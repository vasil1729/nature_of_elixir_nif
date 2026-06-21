import Config

# =============================================================================
# Shared config for all umbrella apps
# =============================================================================

config :logger, :console,
  level: String.to_atom(System.get_env("LOG_LEVEL", "info")),
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :experiment_id]

# Jason for JSON (JSONL metrics, port protocol, UI)
config :phoenix, :json_library, Jason

# Telemetry — attached in lab_web and lab_runner application start
config :lab_core, :telemetry, enabled: true

# Sampler / probes — pinned intervals (docs/03_measurement_protocol.md)
config :lab_core,
  sampler_interval_ms: 100,
  latency_probe_interval_ms: 10,
  system_probe_interval_ms: 500,
  watchdog_interval_ms: 1000

# Scheduler flags are set via ERL_FLAGS env (docker/Dockerfile.elixir_rust)
# and not reconfigurable at runtime. See docs/09_architecture.md.

# Import environment-specific config
import_config "#{config_env()}.exs"
