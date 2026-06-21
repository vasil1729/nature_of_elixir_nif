# ADR 0005: Docker-first execution

## Status

Accepted

## Context

Several experiments (E03, E08, E09, E11, E14, E16, E18, E12) can crash,
hang, or OOM the BEAM. Running these on a host directly:

- E14 (segfault) kills the `elixir` process running Mix — losing the user's
  IEx session and any unsaved work
- E09/E18 (OOM) can trigger the host's OOM-killer, affecting unrelated
  processes
- E03 (infinite loop) hangs the shell if run in-process without a Watchdog
- E12 (10k threads) can exhaust OS thread limits on the host

Two forces:
- **Reproducibility** wants a pinned environment (exact Elixir/OTP/Rust
  versions, exact scheduler flags, exact memory limits)
- **Safety** wants a containment boundary so experiments can't damage the
  host

Docker provides both. The host's Elixir/Rust toolchains may differ from
the pinned versions, making local runs non-reproducible.

## Decision

**Docker-first.** The canonical way to run any experiment is inside the
`lab` Docker container, built from `docker/Dockerfile.elixir_rust`.

The container has:
- Pinned Elixir 1.18.4, OTP 28, Rust 1.92, Rustler 0.38
- Scheduler flags `+S 4:4 +SDcpu 4:4 +SDio 4:4 +A 10`
- Memory limit `--memory 4g --memory-swap 4g` (OOM contained)
- PID limit `--pids-limit 8192` (E12 contained)
- FD limit `--ulimit nofile=4096`
- `--cap-drop ALL`

A `--local` fallback is supported by `scripts/run_experiment.sh` for users
who want fast iteration and accept the risks. The script warns if host
versions don't match the pins.

## Consequences

**Positive:**
- Crashes (E14) only kill the container, not the host session
- OOM (E09/E18) only kills the container
- Thread explosion (E12) is capped
- Every run uses the same versions and flags — reproducible
- New contributors don't need to install Elixir/Rust on their host

**Negative:**
- Docker build adds ~5–10 minutes upfront
- Docker on macOS/Windows adds a layer (Docker Desktop / WSL2)
- `--local` users may see different results than Docker users —
  documented, not prevented
- Container filesystem reset loses `data/` JSONL on restart — Postgres
  mirrors mitigate this

**Neutral:**
- `docker compose up` starts both `lab` and `postgres`; the lab can't run
  the `@oban` experiments without Postgres, which Docker handles
  automatically

## Revisited

_(none yet)_
