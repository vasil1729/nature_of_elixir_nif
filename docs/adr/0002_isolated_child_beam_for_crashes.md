# ADR 0002: Isolated child BEAM for crash experiments

## Status

Accepted

## Context

Five experiments (E03 infinite loop, E08 panic, E11 deadlock, E14 segfault,
E16 node shutdown) are designed to crash or permanently hang the BEAM that
runs them. That's the point — the crash is the evidence.

If these experiments ran in the UI's own BEAM (`:in_process` mode), the
LiveView control room would die with them. The user would lose their
dashboard, their run history, and their browser connection — and wouldn't
even get to see the crash recorded. The lab instrument would be destroyed
by the experiment it's running.

Two forces:
- **Viscerality** wants the crash to be felt — running E14 in-process
  *would* be dramatic.
- **Usability** wants the UI to survive so the crash is *recorded* and
  *explained*, not just experienced.

## Decision

Crash experiments (E03, E08, E11, E14, E16) run in a **separate BEAM OS
process** spawned by the UI's BEAM via `System.cmd`. The child BEAM:

- Gets the same scheduler flags (`+S 4:4 +SDcpu 4:4 +SDio 4:4 +A 10`) for
  reproducibility with in-process experiments
- Streams JSONL metrics to stdout; the UI parses and broadcasts to LiveView
- On death (segfault → exit 11, OOM → exit 137, hang → killed by Watchdog),
  the UI records the exit code and last metrics timestamp as evidence
- The UI shows: "Child BEAM exited with code 11 (SIGSEGV) at T+2.3s.
  Evidence recorded."

Each experiment declares its mode (`:in_process` or `:isolated`) in its
`config.exs`. The UI and CLI enforce the mode; you cannot run E14
in-process through the UI.

## Consequences

**Positive:**
- The UI survives all crash experiments; the user watches the crash
  recorded, not just experienced
- Crash evidence (exit code, last metrics) is preserved
- The same experiment works identically in the UI and the CLI
- Docker containment + child BEAM = double isolation for the worst cases

**Negative:**
- Child BEAM startup adds ~1–2s overhead (irrelevant for multi-second
  experiments)
- Metrics stream via stdout parsing, slightly more fragile than direct
  `:telemetry` (but still JSONL — a known format)
- The child can't share Elixir process state with the UI — but crash
  experiments don't need to

**Neutral:**
- Non-crash experiments stay `:in_process` so the UI freezing on E01
  remains a visceral lesson. The freeze is a *scheduler-blocking*
  demonstration, not a crash — the BEAM survives.

## Revisited

_(none yet)_
