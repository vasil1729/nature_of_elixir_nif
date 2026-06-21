defmodule Lab.Runner.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Stub — commit 10 fills in Repo + Oban + CLI supervisor.
    children = []
    opts = [strategy: :one_for_one, name: Lab.Runner.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
