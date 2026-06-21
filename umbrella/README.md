# umbI'll create a `README.md` for the umbrella to orient contributors.<tool_call>write<arg_key>content</arg_key><arg_value># Umbrella

Elixir umbrella project for the BEAM Characterization Lab. See
[../PLAN.md](../PLAN.md) for the source of truth and
[../docs/09_architecture.md](../docs/09_architecture.md) for the system
architecture.

## Apps

| App | Role |
|-----|------|
| `lab_core` | Instrumentation: Sampler, LatencyProbe, SystemProbe, Watchdog, Reporter, TelemetryPub |
| `lab_native` | Single Rustler crate exposing every NIF (Normal + Dirty variants) |
| `lab_port` | Single Rust port binary (stdin/stdout JSON protocol) |
| `lab_web` | Phoenix LiveView control room (`:4000`) |
| `lab_runner` | CLI for CI/headless experiment execution |

## Build

```bash
mix deps.get
mix compile
```

## Run

```bash
mix phx.server           # from lab_web — starts the control room
mix test                 # fast harness tests
mix test --only slow     # full characterization suite
mix test --only crash    # crash experiments (Docker only!)
```

See [../docs/13_runbook.md](../docs/13_runbook.md) for the complete guide.
