# E03: Infinite Loop (Normal vs Dirty)

**Theme:** A -- Scheduler Blocking  |  **Mode:** isolated  |  **Tags:** @crash @slow
**Related:** E01, E02

## Hypothesis
An infinite-loop Normal NIF causes the BEAM VM to become unresponsive (all schedulers starved); the Watchdog kills it. The same loop on a DirtyCpu NIF leaves the VM alive.

## Background
An infinite NIF on a normal scheduler prevents the scheduler from ever returning control. On a dirty CPU scheduler the loop is isolated to that pool. The child BEAM is isolated (ADR 0002) so the UI survives.

## Setup
- NIF: `Lab.Native.infinite_loop/0` (Normal)
- Mode: isolated child BEAM
- Watchdog timeout: 10 000ms

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| `variant` | normal | normal/dirty | which NIF arm to run |

## Execution
- CLI: `scripts/run_experiment.sh E03`
- UI: Catalog -> E03 -> Run
- Test: `mix test experiments/E03_infinite_loop/`

## Expected Outcome
- Normal arm: Watchdog kills; exit_code != 0
- Dirty arm: BEAM survives

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis with evidence]

## References
- docs/01_beam_scheduler_model.md
- docs/05_safety_isolation.md
- ADR 0002
