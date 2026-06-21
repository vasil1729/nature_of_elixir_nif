# ADR 0004: Strict threshold assertions

## Status

Accepted

## Context

Each experiment is an ExUnit test. The question: what should the test
assert?

Three options:
1. **Binary only** — assert crash/no-crash and structural invariants (dirty
   schedulers active, process alive). Numeric metrics recorded but not
   asserted. Loose, portable across hardware.
2. **Strict thresholds** — assert numeric thresholds from the hypothesis
   (e.g. p99 < 50ms, RSS > 100MB). Fails if BEAM behavior changes. Strongest
   regression value.
3. **Thresholds with tolerances** — strict on powerful hardware, but
   thresholds scale by CPU count/RAM. More work, runs meaningfully on any
   machine.

The lab's purpose is to *characterize* BEAM behavior with quantitative
evidence. "Binary only" would make every experiment a pass/fail yes/no —
losing the numbers that make the lab valuable. "Tolerances" adds complexity
for a benefit (portability) that Docker pinning already provides.

## Decision

**Strict numeric thresholds.** Each experiment's `config.exs` declares
thresholds derived from its hypothesis. The test asserts all thresholds
after the run.

Thresholds are absolute (ms, %, MB, count) and chosen to hold on the
pinned configuration (`+S 4:4`, Docker's `--memory 4g`, modern x86_64).
They have headroom (not set at the exact measured value) so normal
run-to-run variance doesn't cause flakes.

If a threshold is genuinely wrong (not reflecting a real BEAM property),
the process in [06_reproducibility_protocol.md](../06_reproducibility_protocol.md)
governs the adjustment — never silently loosen to make CI green.

## Consequences

**Positive:**
- Every experiment produces a pass/fail signal backed by numbers
- Regressions across BEAM/Rustler versions are detected automatically
- The final report's conclusions are defensible: "p99 latency was 3.1ms,
  threshold was 50ms, test passed"
- Thresholds are auditable in `config.exs` — not magic numbers in test code

**Negative:**
- Thresholds may need tuning when first run on hardware significantly
  slower/faster than the reference — documented in the runbook
- A threshold set too tight causes flakes; too loose misses real changes
- "Strict" doesn't mean "exact" — headroom is required, which is a judgment
  call

**Neutral:**
- The `--compare` flag (golden baselines) complements strict thresholds:
  thresholds catch regressions that violate the hypothesis; baselines
  catch drift that stays within thresholds but is still meaningful.

## Revisited

_(none yet)_
