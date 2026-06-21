import Config

# lab_core: pinned intervals (already in root config; can be overridden here)
config :lab_core,
  sampler_interval_ms: 100,
  latency_probe_interval_ms: 10,
  system_probe_interval_ms: 500,
  watchdog_interval_ms: 1000
