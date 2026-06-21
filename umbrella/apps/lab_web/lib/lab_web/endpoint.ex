defmodule LabWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :lab_web

  # The session will be stored in the cookie and signed.
  # The key must be a list of atoms (config in config/dev.exs or prod.exs).
  @session_options [
    store: :cookie,
    key: "_lab_web_key",
    signing_salt: System.get_env("LIVE_VIEW_SALT", "lab_dev_salt_research_only"),
    same_site: "lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :lab_web,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.Session, @session_options
  plug LabWeb.Router
end
