import Config

# Dev: Phoenix on :4000, LiveView reload, Postgres for Oban + history.
# Apps are configured conditionally — not all apps are wired until Phase 1
# is complete. This avoids "application not available" warnings during
# incremental scaffold development.

if Code.ensure_loaded?(LabWeb.Endpoint) do
  config :lab_web, LabWeb.Endpoint,
    url: [host: "localhost", port: 4000],
    http: [ip: {0, 0, 0, 0}, port: 4000],
    debug_errors: true,
    code_reloader: true,
    check_origin: false,
    watchers: [],
    live_view: [signing_salt: System.get_env("LIVE_VIEW_SALT", "lab_dev_salt_research_only")]
end

if Code.ensure_loaded?(Lab.Repo) do
  config :lab_runner, Lab.Repo,
    username: "lab",
    password: "lab",
    database: "lab",
    hostname: System.get_env("POSTGRES_HOST", "localhost"),
    port: 5432,
    pool_size: 10

  config :lab_web, Lab.Repo,
    username: "lab",
    password: "lab",
    database: "lab",
    hostname: System.get_env("POSTGRES_HOST", "localhost"),
    port: 5432,
    pool_size: 10

  config :lab_runner, Oban,
    engine: Oban.Engines.Basic,
    queues: [default: 10, experiments: 20],
    repo: Lab.Repo

  config :lab_web, Oban,
    engine: Oban.Engines.Basic,
    queues: [default: 10, experiments: 20],
    repo: Lab.Repo
end
