defmodule Lab.Core do
  @moduledoc """
  Instrumentation for the BEAM Characterization Lab.

  Provides four probes that sample BEAM and OS state at pinned intervals
  (see docs/03_measurement_protocol.md):

  * `Lab.Core.Sampler`       — scheduler wall time, run queues, process count,
    reductions, GC, BEAM memory (100ms)
  * `Lab.Core.LatencyProbe`  — round-trip ping latency p50/p99/max (10ms)
  * `Lab.Core.SystemProbe`   — RSS, threads, FDs from /proc (500ms)
  * `Lab.Core.Watchdog`      — liveness + time-budget + memory guard (1000ms)

  All probes emit `:telemetry` events on the `[:lab, *, *]` namespace and
  optionally write JSONL to `data/<experiment_id>/`. `Lab.Core.TelemetryPub`
  fans telemetry out to Phoenix.PubSub (for LiveView) when available.

  `Lab.Core.Reporter` renders `report.md` from JSONL + assertion results.
  """

  @doc """
  Starts a supervision tree of all four probes for an experiment run.

  ## Options

    * `:experiment_id` — atom (e.g. `:E01`); required for data_path output
    * `:data_path`     — directory for JSONL output (default: `data/<id>/`)
    * `:time_budget_ms` — Watchdog kills the run after this (default: 120_000)
    * `:memory_limit_mb` — Watchdog flags OOM above this (default: 3_500)

  Returns `{:ok, sup_pid}`. Call `Lab.Core.stop_supervisor(sup_pid)` to stop.
  """
  def start_probes(opts) do
    import Supervisor, only: [start_link: 2]

    experiment_id = Keyword.fetch!(opts, :experiment_id)
    data_path = Keyword.get(opts, :data_path, default_data_path(experiment_id))
    File.mkdir_p!(data_path)

    children = [
      {Lab.Core.Sampler, [experiment_id: experiment_id, data_path: data_path]},
      {Lab.Core.LatencyProbe, [experiment_id: experiment_id, data_path: data_path]},
      {Lab.Core.SystemProbe, [experiment_id: experiment_id, data_path: data_path]},
      {Lab.Core.Watchdog, Keyword.take(opts, [:time_budget_ms, :memory_limit_mb]) ++
                            [experiment_id: experiment_id, data_path: data_path]}
    ]

    start_link(children, strategy: :one_for_one, name: {:via, Registry, {Lab.Core.Registry, experiment_id}})
  end

  @doc "Stops a probe supervision tree started by `start_probes/1`."
  def stop_probes(sup_pid) do
    Supervisor.stop(sup_pid, :normal)
  end

  @doc "Default JSONL output directory for an experiment."
  def default_data_path(experiment_id) do
    id = experiment_id |> to_string() |> String.downcase()
    Path.join(["data", id])
  end

  @doc "Returns the current monotonic timestamp in milliseconds."
  def monotonic_ms do
    System.monotonic_time(:millisecond)
  end
end
