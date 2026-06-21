defmodule Lab.Web.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Attach telemetry handlers for lab_core probes
    Lab.Core.TelemetryPub.attach()

    children = [
      {Phoenix.PubSub, name: Lab.PubSub},
      {Task.Supervisor, name: LabWeb.TaskSupervisor},
      LabWeb.Telemetry,
      LabWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Lab.Web.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    LabWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
