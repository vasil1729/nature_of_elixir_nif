defmodule Lab.Executor do
  @moduledoc """
  Experiment execution dispatch — chooses in_process or isolated mode
  based on the experiment's config.

  See docs/07_ui_architecture.md and ADR 0002.
  """

  @doc "Runs an experiment using the mode declared in its config."
  def run(config, params, opts \\ []) do
    case Map.get(config, :mode, :in_process) do
      :in_process -> Lab.Executor.InProcess.run(config, params, opts)
      :isolated -> Lab.Executor.Isolated.run(config, params, opts)
    end
  end
end
