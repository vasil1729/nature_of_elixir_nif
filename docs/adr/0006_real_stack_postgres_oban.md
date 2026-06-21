# ADR 0006: Real stack — Postgres + Oban + Ecto

## Status

Accepted

## Context

E20 (Oban Interaction) and E21 (Real PDF Workload) probe how long native
operations interact with real-world Elixir infrastructure. Two approaches:

1. **Lightweight** — hand-rolled job queue (no Postgres); pure-Rust PDF
   library. Zero external services. Easy setup.
2. **Real stack** — actual Oban + Postgres + Ecto; pdfium C bindings via
   `pdfium-render`. Most realistic, heaviest setup.

The lab's purpose is to bridge synthetic stress tests and production-like
workloads. E20's question — "how do long native operations interact with
Oban?" — is only meaningful if Oban is *actually* there. A hand-rolled
queue wouldn't answer the question; it would answer "how do long native
operations interact with *our toy queue*?"

Same for E21: real PDF processing via pdfium is what production teams
actually use. A pure-Rust toy parser wouldn't reflect the C-binding
realities (memory, segfault risk, blocking calls) that motivate the
DirtyCpu vs Port question.

## Decision

**Real stack.** `docker-compose.yml` includes a `postgres` service.
`lab_runner` and `lab_web` depend on Oban + Ecto + Postgrex.

E20 uses Oban to enqueue 100 jobs, each calling a 30-second native
workload. E21 uses Oban to enqueue 1000 concurrent PDF jobs (NIF, Dirty
NIF, and Port arms).

Postgres also serves as the run-history store for the UI's History page
(see [07_ui_architecture.md](../07_ui_architecture.md)) — a second use
that justifies the service even outside E20/E21.

## Consequences

**Positive:**
- E20/E21 answers are directly applicable to production teams using Oban
- Postgres doubles as run-history storage (no extra service needed)
- The UI's run comparison feature works off Postgres queries
- Oban's own queue instrumentation is available as a cross-reference

**Negative:**
- `docker-compose.yml` needs a second service (postgres) — modest
  complexity
- `@oban`-tagged experiments can't run without Postgres — excluded by
  default, opt-in via `mix test --only oban`
- Postgres startup adds ~3s to `docker compose up`
- CI needs a `postgres` service container

**Neutral:**
- Postgres data persists in a named volume (`pgdata`) across container
  restarts

## Revisited

_(none yet)_
