defmodule LabWeb.Telemetry do
  @moduledoc false
  use Supervisor

  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children =
      if Application.get_env(:lab_web, :telemetry_reporter, true) do
        [{Telemetry.Metrics.ConsoleReporter, metrics: metrics()}]
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # VM metrics
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.memory.processes", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),
      last_value("vm.system_counts.process_count"),
      # Lab-specific metrics (from lab_core)
      last_value("lab.sampler.sample.metrics.run_queue"),
      last_value("lab.sampler.sample.metrics.process_count"),
      last_value("lab.latency.window.metrics.p99_us", unit: :microsecond),
      last_value("lab.system.sample.metrics.rss_kb", unit: :kilobyte)
    ]
  end
end
