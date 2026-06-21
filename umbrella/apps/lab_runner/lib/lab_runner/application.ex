defmodule Lab.Runner.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Attach lab_core telemetry for headless metric collection
    Lab.Core.TelemetryPub.attach()

    children =
      if repo_enabled?() do
        [
          Lab.Repo,
          {Oban, oban_config()}
        ]
      else
        []
      end

    opts = [strategy: :one_for_one, name: Lab.Runner.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp repo_enabled? do
    Code.ensure_loaded?(Lab.Repo) and
      Application.get_env(:lab_runner, Lab.Repo) != nil
  end

  defp oban_config do
    Application.get_env(:lab_runner, Oban) ||
      [engine: Oban.Engines.Basic, queues: [default: 10, experiments: 20], repo: Lab.Repo]
  end
end
