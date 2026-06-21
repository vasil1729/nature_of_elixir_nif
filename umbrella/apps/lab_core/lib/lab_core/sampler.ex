defmodule Lab.Core.Sampler do
  @moduledoc """
  Polls BEAM scheduler statistics at a pinned interval (100ms default).

  Computes per-scheduler utilization by diffing
  `:erlang.statistics(:scheduler_wall_time)` between samples. Emits
  `[:lab, :sampler, :sample]` telemetry with a `Lab.Core.Metrics` struct
  and writes JSONL to `data/<id>/sampler.jsonl`.

  See docs/01_beam_scheduler_model.md and docs/03_measurement_protocol.md.
  """

  use GenServer
  require Logger

  @default_interval_ms 100

  @doc """
  Options:

    * `:interval_ms`    — poll interval (default: 100)
    * `:experiment_id`  — atom id for JSONL output (required)
    * `:data_path`      — directory for JSONL output (required)
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    exp_id = Keyword.fetch!(opts, :experiment_id)
    data_path = Keyword.fetch!(opts, :data_path)

    {:ok, writer} = Lab.Core.JsonlWriter.start_link(Path.join(data_path, "sampler.jsonl"))

    # Prime scheduler_wall_time so the first sample has a diff baseline.
    :erlang.statistics(:scheduler_wall_time)

    state = %{
      interval: interval,
      exp_id: exp_id,
      writer: writer,
      prev: nil
    }

    schedule_next(state)
    {:ok, state}
  end

  defp schedule_next(%{interval: interval}) do
    Process.send_after(self(), :sample, interval)
  end

  @impl true
  def handle_info(:sample, state) do
    sample = take_sample(state)
    Lab.Core.JsonlWriter.write(state.writer, sample)

    :telemetry.execute(
      [:lab, :sampler, :sample],
      %{metrics: sample},
      %{experiment_id: state.exp_id}
    )

    schedule_next(state)
    {:noreply, %{state | prev: sample}}
  end

  @impl true
  def terminate(_reason, %{writer: writer}) do
    Lab.Core.JsonlWriter.close(writer)
  end

  @doc false
  def take_sample(state) do
    {:scheduler_wall_time, entries} = :erlang.statistics(:scheduler_wall_time)

    {normal_util, dirty_cpu_util, dirty_io_util} =
      compute_utils(entries, state.prev && state.prev.sched_util_raw)

    normal_count = :erlang.system_info(:schedulers)
    dirty_cpu_count = :erlang.system_info(:dirty_cpu_schedulers)
    dirty_io_count = :erlang.system_info(:dirty_io_schedulers)

    {:garbage_collection, gc_count, words_reclaimed, _} =
      :erlang.statistics(:garbage_collection)

    %Lab.Core.Metrics{
      ts: Lab.Core.monotonic_ms(),
      scheduler_count: normal_count,
      dirty_cpu_count: dirty_cpu_count,
      dirty_io_count: dirty_io_count,
      online_schedulers: :erlang.system_info(:schedulers_online),
      sched_util: normal_util,
      dirty_cpu_util: dirty_cpu_util,
      dirty_io_util: dirty_io_util,
      run_queue: :erlang.statistics(:run_queue),
      process_count: :erlang.system_info(:process_count),
      reductions: :erlang.statistics(:reductions),
      gc_count: gc_count,
      words_reclaimed: words_reclaimed,
      beam_total_memory: :erlang.memory(:total),
      beam_process_memory: :erlang.memory(:processes),
      beam_binary_memory: :erlang.memory(:binary),
      beam_ets_memory: :erlang.memory(:ets)
    }
    # Stash raw wall-time entries for the next diff (not serialized).
    |> Map.put(:sched_util_raw, entries)
  end

  # Compute per-scheduler utilization as a list of {id, util 0.0..1.0}.
  # Splits into normal / dirty_cpu / dirty_io by scheduler id:
  #   ids 1..schedulers                            -> normal
  #   ids schedulers+1 .. schedulers+dirty_cpu     -> dirty cpu
  #   ids schedulers+dirty_cpu+1 .. +dirty_io      -> dirty io
  defp compute_utils(entries, nil), do: split_utils(entries, nil)

  defp compute_utils(entries, prev) when is_list(prev) do
    split_utils(entries, prev)
  end

  defp split_utils(entries, prev) do
    normal_count = :erlang.system_info(:schedulers)
    dirty_cpu_count = :erlang.system_info(:dirty_cpu_schedulers)

    normal_max = normal_count
    dirty_cpu_max = normal_count + dirty_cpu_count

    {normal, dirty_cpu, dirty_io} =
      Enum.reduce(entries, {[], [], []}, fn {id, busy, idle}, {n, dc, dio} ->
        util = diff_util(id, busy, idle, prev)

        cond do
          id <= normal_max -> {[{id, util} | n], dc, dio}
          id <= dirty_cpu_max -> {n, [{id, util} | dc], dio}
          true -> {n, dc, [{id, util} | dio]}
        end
      end)

    {Enum.reverse(normal), Enum.reverse(dirty_cpu), Enum.reverse(dirty_io)}
  end

  defp diff_util(_id, _busy, _idle, nil), do: 0.0

  defp diff_util(id, busy, idle, prev) when is_list(prev) do
    case Enum.find(prev, fn {pid, _} -> pid == id end) do
      {^id, prev_busy, prev_idle} ->
        db = busy - prev_busy
        di = idle - prev_idle
        total = db + di

        if total > 0, do: db / total, else: 0.0

      nil ->
        0.0
    end
  end

  # Public helper for tests / Reporter: aggregate utilization stats.
  @doc "Returns {mean, max} utilization from a list of {id, util} tuples."
  def aggregate(utils) when is_list(utils) do
    case utils do
      [] -> {0.0, 0.0}
      vals ->
        us = Enum.map(vals, fn {_, u} -> u end)
        {Enum.sum(us) / length(us), Enum.max(us)}
    end
  end
end
