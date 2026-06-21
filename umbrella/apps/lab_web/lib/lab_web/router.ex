defmodule LabWeb.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LabWeb.Layouts, :root}
    plug :protect_from_forgery
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LabWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/catalog", CatalogLive, :index
    live "/catalog/:id/run", RunLive, :run
    live "/history", HistoryLive, :index
    live "/reports/:id", ReportLive, :show
    live "/reports/final", ReportLive, :final
    live "/docs", DocsLive, :index
    live "/docs/:path", DocsLive, :show
  end
end
