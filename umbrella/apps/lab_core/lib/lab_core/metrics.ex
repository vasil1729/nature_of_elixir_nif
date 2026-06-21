defmodule Lab.Core.Metrics do
  @moduledoc """
  Struct definitions for the metric samples produced by lab_core probes.
  All structs serialize to JSON via Jason for JSONL output and telemetry.
  """

  @derive {Jason.Encoder, only: [:ts, :scheduler_count, :dirty_cpu_count,
           :dirty_io_count, :online_schedulers, :sched_util, :dirty_cpu_util,
           :dirty_io_util, :run_queue, :process_count, :reductions,
           :gc_count, :words_reclaimed, :beam_total_memory,
           :beam_process_memory, :beam_binary_memory, :beam_ets_memory]}
  defstruct [:ts, :scheduler_count, :dirty_cpu_count, :dirty_io_count,
             :online_schedulers, :sched_util, :dirty_cpu_util, :dirty_io_util,
             :run_queue, :process_count, :reductions, :gc_count,
             :words_reclaimed, :beam_total_memory, :beam_process_memory,
             :beam_binary_memory, :beam_ets_memory]

  @type t :: %__MODULE__{}
end

defmodule Lab.Core.LatencyMetrics do
  @derive {Jason.Encoder, only: [:ts, :round_trip_us]}
  defstruct [:ts, :round_trip_us]

  @type t :: %__MODULE__{}
end

defmodule Lab.Core.LatencyWindow do
  @derive {Jason.Encoder, only: [:ts, :p50_us, :p99_us, :max_us, :count]}
  defstruct [:ts, :p50_us, :p99_us, :max_us, :count]

  @type t :: %__MODULE__{}
end

defmodule Lab.Core.SystemMetrics do
  @derive {Jason.Encoder, only: [:ts, :rss_kb, :threads, :fds, :cpu_user_jiffies,
           :cpu_system_jiffies]}
  defstruct [:ts, :rss_kb, :threads, :fds, :cpu_user_jiffies, :cpu_system_jiffies]

  @type t :: %__MODULE__{}
end

defmodule Lab.Core.WatchdogEvent do
  @derive {Jason.Encoder, only: [:ts, :event, :detail]}
  defstruct [:ts, :event, :detail]

  @type t :: %__MODULE__{}
end
