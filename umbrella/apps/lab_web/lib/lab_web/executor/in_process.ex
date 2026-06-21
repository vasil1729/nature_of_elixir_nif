defmodule Lab.Executor.InProcess do
  @moduledoc """
  Runs an experiment in the UI's own BEAM (for non-crash experiments).

  Delegates to Lab.Runner.run/2, which starts lab_core probes, executes
  the workload, and generates the report. The UI may freeze during
  scheduler-blocking experiments — that freezing is evidence.

  See docs/07_ui_architecture.md and ADR 0002.
  """

  require Logger

  @doc "Runs an in-process experiment. Returns Lab.Runner.run/2 result."
  def run(config, params, opts \\ []) do
    Logger.info("[InProcess] Running #{config.id} with #{inspect(params)}")
    Lab.Runner.run_with_config(config, Keyword.merge(opts, params: params))
  end
end
