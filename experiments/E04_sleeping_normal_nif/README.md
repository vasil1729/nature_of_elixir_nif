# E04: Sleeping Normal NIF

**Theme:** A -- Scheduler Blocking  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E05, E06

## Hypothesis
A Normal-scheduled NIF that sleeps (blocks) for 60 s wastes a BEAM scheduler thread for the entire duration, starving Elixir processes scheduled on that thread.

## Background
OS-level sleep in a Normal NIF holds the BEAM scheduler thread in a blocking syscall. See docs/01_beam_scheduler_model.md.

## Setup
- NIF: `Lab.Native.sleep_for_ms/1` (Normal-scheduled)
- Duration: 60 000ms default
- Sampler: 100ms  |  LatencyProbe: 10ms

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| `duration_ms` | 60_000 | 1_000-120_000 | must be long enough to observe scheduler stall |

## Execution
- CLI: `scripts/run_experiment.sh E04`
- UI: Catalog -> E04 -> Run
- Test: `mix test experiments/E04_sleeping_normal_nif/`

## Expected Outcome
- Scheduler thread occupied for >= 59 000ms
- Run queue grows for Elixir processes on that scheduler

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis with numbers]

## References
- docs/01_beam_scheduler_model.md
- E05 (dirty variant)
