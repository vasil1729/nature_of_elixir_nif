defmodule Lab.Web.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Stub — commit 9 fills in Phoenix endpoint + supervisor.
    children = []
    opts = [strategy: :one_for_one, name: Lab.Web.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
