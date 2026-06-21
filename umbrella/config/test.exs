import Config

# Test: in-memory Postgres (or skip DB tests if no postgres).
# Configured conditionally until apps are wired.

if Code.ensure_loaded?(LabWeb.Endpoint) do
  config :lab_web, LabWeb.Endpoint,
    url: [host: "localhost", port: 4002],
    http: [ip: {0, 0, 0, 0}, port: 4002],
    secret_key_base: "lab_test_secret_key_base_for_research_test_only",
    server: false
end

if Code.ensure_loaded?(Lab.Repo) do
  config :lab_runner, Lab.Repo,
    username: "lab",
    password: "lab",
    database: "lab_test",
    hostname: System.get_env("POSTGRES_HOST", "localhost"),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10

  config :lab_web, Lab.Repo,
    username: "lab",
    password: "lab",
    database: "lab_test",
    hostname: System.get_env("POSTGRES_HOST", "localhost"),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end

# ExUnit: default excludes @slow/@crash/@oban/@pdf (opt-in per docs/06)
config :lab_core, :test_excludes, [:slow, :crash, :oban, :pdf]

# Disable telemetry console reporter in tests
config :lab_web, :telemetry_reporter, false

config :logger, level: :warning
