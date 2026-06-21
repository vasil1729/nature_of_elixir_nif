# ADR 0008: UI primary, CLI for CI

## Status

Accepted

## Context

The lab has two use cases:
1. **Interactive exploration** — browse experiments, tune parameters,
   watch the BEAM misbehave in real time, compare runs, read reports
2. **Headless reproduction** — CI, regression testing, "fork and verify"

Two forces:
- **Approachability** wants a UI — `docker compose up` → browser → click
  → watch. No Elixir knowledge required to *use* the lab (only to extend
  it).
- **Reproducibility** wants a CLI — `mix test --only slow` in CI, machine-
  verifiable, no human in the loop.

These aren't in conflict. The lab should be *usable* via UI and
*verifiable* via CLI. The question is which is the **primary** entry
point — the one `docker compose up` leads to.

Making the CLI primary would mean the UI is an optional `--ui` flag, and
CLI users never see Phoenix. That's less approachable for the majority of
users who want to *see* the behavior, not parse JSONL.

## Decision

**UI primary.** `docker compose up` launches Phoenix LiveView at
`localhost:4000` — that's the lab. The CLI (`scripts/run_experiment.sh`,
`mix test`) exists for CI and headless reproduction.

Both front-ends share the same foundation (`lab_core`, `lab_native`,
`lab_port`). No experiment logic is duplicated — the UI and CLI both call
`Lab.Runner.run(config)`, which orchestrates the workload and
instrumentation.

## Consequences

**Positive:**
- `docker compose up` → browser → done. Lowest possible friction.
- The UI freezing on E01 is a visceral lesson only the primary-UI choice
  enables — a CLI user sees a 30-second pause in logs, not a frozen
  dashboard
- Run history, report browsing, and doc browsing all live in the UI — one
  place
- CI uses the CLI; humans use the UI; neither gets in the other's way

**Negative:**
- `docker compose up` starts Phoenix even for users who only want the CLI
  — minor overhead (a few MB, one extra process). They can `docker compose
  exec lab scripts/run_experiment.sh E02` and ignore `:4000`.
- The UI is more code to maintain than a CLI-only lab would be — but the
  UI is the lab's distinguishing feature, not a luxury

**Neutral:**
- The CLI is not a "second-class" citizen — it's the CI path and the
  reproducibility mechanism. The UI is the *default*; the CLI is the
  *verifiable*.

## Revisited

_(none yet)_
