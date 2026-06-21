import Config

# Prod: served from Docker; DATABASE_URL from env
database_url =
  System.get_env("DATABASE_URL") ||
    raise "DATABASE_URL is required in prod"

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise "SECRET_KEY_BASE is required in prod"

config :lab_web, LabWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST", "localhost"), port: 4000, scheme: "http"],
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: secret_key_base,
  server: true,
  code_reloader: false

config :lab_web, Lab.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

config :lab_runner, Lab.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

config :lab_web, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, experiments: 20],
  repo: Lab.Repo

config :lab_runner, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, experiments: 20],
  repo: Lab.Repo

config :logger, level: :info
