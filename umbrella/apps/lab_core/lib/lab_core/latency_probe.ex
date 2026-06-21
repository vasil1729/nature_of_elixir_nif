defmodule Lab.Core.LatencyProbe do
  @moduledoc """
  Measures round-trip message latency to a trivial Elixir process.

  Every `interval_ms` (default 10ms), the probe sends `{:ping, from}` to a
  ping target process and measures the time until it receives `{:pong, ts}`.
  The round-trip time in microseconds is recorded.

  Every 1s, the probe computes p50/p99/max over the last 1000 samples and
  emits `[:lab, :latency, :window]` telemetry with a `Lab.Core.LatencyWindow`.

  Individual samples emit `[:lab, :latency, :sample]` and write to
  `data/<id>/latency.jsonl`.

  See docs/03_measurement_protocol.md.
  """

  use GenServer

  @default_interval_ms 10
  @window_size 1000
  @window_emit_ms 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    exp_id = Keyword.fetch!(opts, :experiment_id)
    data_path = Keyword.fetch!(opts, :data_path)

    {:ok, writer} = Lab.Core.JsonlWriter.start_link(Path.join(data_path, "latency.jsonl"))

    # Spawn the ping target — a trivial process that replies immediately.
    ping_pid = spawn_link(fn -> ping_loop() end)

    state = %{
      interval: interval,
      exp_id: exp_id,
      writer: writer,
      ping_pid: ping_pid,
      window: [],
      last_window_emit: System.monotonic_time(:millisecond)
    }

    send(self(), :ping)
    schedule_window(state)
    {:ok, state}
  end

  defp schedule_window(_state) do
    Process.send_after(self(), :emit_window, @window_emit_ms)
  end

  @impl true
  def handle_info(:ping, state) do
    ts = System.monotonic_time(:microsecond)
    send(state.ping_pid, {:ping, self(), ts})
    Process.send_after(self(), :ping, state.interval)
    {:noreply, state}
  end

  @impl true
  def handle_info({:pong, sent_ts}, state) do
    now = System.monotonic_time(:microsecond)
    round_trip = now - sent_ts

    sample = %Lab.Core.LatencyMetrics{ts: Lab.Core.monotonic_ms(), round_trip_us: round_trip}
    Lab.Core.JsonlWriter.write(state.writer, sample)

    :telemetry.execute(
      [:lab, :latency, :sample],
      %{metrics: sample},
      %{experiment_id: state.exp_id}
    )

    window = [round_trip | state.window] |> Enum.take(@window_size)
    {:noreply, %{state | window: window}}
  end

  @impl true
  def handle_info(:emit_window, state) do
    window_sample = compute_window(state.window, state.exp_id)

    if window_sample do
      Lab.Core.JsonlWriter.write(state.writer, window_sample)

      :telemetry.execute(
        [:lab, :latency, :window],
        %{metrics: window_sample},
        %{experiment_id: state.exp_id}
      )
    end

    schedule_window(state)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{writer: writer}) do
    Lab.Core.JsonlWriter.close(writer)
  end

  defp compute_window([], _exp_id), do: nil

  defp compute_window(window, _exp_id) do
    sorted = Enum.sort(window)
    count = length(sorted)
    p50 = percentile(sorted, count, 50)
    p99 = percentile(sorted, count, 99)
    max_us = List.last(sorted)

    %Lab.Core.LatencyWindow{
      ts: Lab.Core.monotonic_ms(),
      p50_us: p50,
      p99_us: p99,
      max_us: max_us,
      count: count
    }
  end

  defp percentile(sorted, count, pct) do
    # Nearest-rank percentile
    rank = max(1, ceil(count * pct / 100))
    Enum.at(sorted, rank - 1)
  end

  defp ping_loop do
    receive do
      {:ping, from, ts} ->
        send(from, {:pong, ts})
        ping_loop()
    end
  end
end
