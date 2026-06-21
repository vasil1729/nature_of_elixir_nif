defmodule Lab.Core.Watchdog do
  @moduledoc """
  Monitors an experiment run for liveness, time-budget violations, and
  memory-guard breaches.

  Polls every 1000ms. Emits `[:lab, :watchdog, :event]` telemetry with a
  `Lab.Core.WatchdogEvent` struct and writes JSONL to
  `data/<id>/watchdog.jsonl`.

  Events emitted:

    * `:started`        — watchdog started, time_budget + memory_limit set
    * `:heartbeat`      — normal poll; includes run_queue + schedulers_blocked
    * `:degraded`       — run_queue above threshold for > 1s
    * `:schedulers_blocked` — a scheduler at 100% util for > 1s
    * `:time_budget_exceeded` — run exceeded time_budget_ms; kills the run
    * `:memory_guard`   — RSS exceeded memory_limit_mb; kills the run
    * `:stopped`        — watchdog stopped cleanly

  See docs/05_safety_isolation.md.
  """

  use GenServer

  @default_interval_ms 1000
  @default_time_budget_ms 120_000
  @default_memory_limit_mb 3_500
  @degraded_queue_threshold 100

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    exp_id = Keyword.fetch!(opts, :experiment_id)
    data_path = Keyword.fetch!(opts, :data_path)
    time_budget = Keyword.get(opts, :time_budget_ms, @default_time_budget_ms)
    memory_limit = Keyword.get(opts, :memory_limit_mb, @default_memory_limit_mb)

    {:ok, writer} = Lab.Core.JsonlWriter.start_link(Path.join(data_path, "watchdog.jsonl"))

    emit(writer, exp_id, :started, %{time_budget_ms: time_budget, memory_limit_mb: memory_limit})

    state = %{
      interval: interval,
      exp_id: exp_id,
      writer: writer,
      start_ts: System.monotonic_time(:millisecond),
      time_budget: time_budget,
      memory_limit: memory_limit,
      degraded_since: nil,
      blocked_since: nil,
      killed: false,
      run_task: Keyword.get(opts, :run_task),
      prev_reductions: :erlang.statistics(:reductions)
    }

    schedule_next(state)
    {:ok, state}
  end

  defp schedule_next(%{interval: interval}) do
    Process.send_after(self(), :check, interval)
  end

  @impl true
  def handle_info(:check, %{killed: true} = state) do
    {:noreply, state}
  end

  def handle_info(:check, state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.start_ts

    # Time budget
    if elapsed > state.time_budget do
      emit(state.writer, state.exp_id, :time_budget_exceeded, %{elapsed_ms: elapsed})
      kill_run(state)
      {:noreply, %{state | killed: true}}
    else
      rq = :erlang.statistics(:run_queue)
      blocked = schedulers_blocked?(state)

      # Degraded detection (run queue > threshold for > 1s)
      degraded_since =
        cond do
          rq > @degraded_queue_threshold and is_nil(state.degraded_since) ->
            now

          rq <= @degraded_queue_threshold ->
            nil

          true ->
            state.degraded_since
        end

      if degraded_since && now - degraded_since > 1000 && is_nil(state.degraded_since) do
        emit(state.writer, state.exp_id, :degraded, %{run_queue: rq})
      end

      # Schedulers blocked detection (no reduction progress despite run queue)
      blocked_since =
        cond do
          blocked and is_nil(state.blocked_since) -> now
          not blocked -> nil
          true -> state.blocked_since
        end

      if blocked_since && now - blocked_since > 1000 && is_nil(state.blocked_since) do
        emit(state.writer, state.exp_id, :schedulers_blocked, %{})
      end

      # Memory guard
      case rss_mb() do
        nil ->
          :ok

        rss when rss > state.memory_limit ->
          emit(state.writer, state.exp_id, :memory_guard, %{rss_mb: rss, limit_mb: state.memory_limit})
          kill_run(state)
          {:noreply, %{state | killed: true}}

        _ ->
          :ok
      end

      emit(state.writer, state.exp_id, :heartbeat, %{
        elapsed_ms: elapsed,
        run_queue: rq,
        schedulers_blocked: blocked
      })

      current_reductions = :erlang.statistics(:reductions)
      schedule_next(state)

      {:noreply,
       %{state |
         degraded_since: degraded_since,
         blocked_since: blocked_since,
         prev_reductions: current_reductions}}
    end
  end

  @impl true
  def terminate(_reason, %{writer: writer, killed: killed} = state) do
    emit(writer, state.exp_id, :stopped, %{killed: killed})
    Lab.Core.JsonlWriter.close(writer)
  end

  defp schedulers_blocked?(state) do
    # Heuristic: if run_queue > 0 but total reductions haven't progressed
    # since the last poll, a scheduler is blocked. This catches the classic
    # normal-NIF-starvation case (E01) without needing access to the Sampler.
    current = :erlang.statistics(:reductions)
    rq = :erlang.statistics(:run_queue)
    rq > 0 and current == state.prev_reductions
  end

  defp rss_mb do
    pid_str = :os.getpid() |> to_string()

    case File.read("/proc/#{pid_str}/status") do
      {:ok, content} ->
        case Regex.run(~r/^VmRSS:\s+(\d+)\s+kB$/m, content, capture: :all_but_first) do
          [val] -> String.to_integer(val) |> div(1024)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp kill_run(state) do
    if state.run_task do
      Task.shutdown(state.run_task, :brutal_kill)
    end
  end

  defp emit(writer, exp_id, event, detail) do
    evt = %Lab.Core.WatchdogEvent{ts: Lab.Core.monotonic_ms(), event: event, detail: detail}
    Lab.Core.JsonlWriter.write(writer, evt)

    :telemetry.execute(
      [:lab, :watchdog, :event],
      %{metrics: evt},
      %{experiment_id: exp_id}
    )
  end
end
