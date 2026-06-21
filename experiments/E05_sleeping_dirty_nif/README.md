# E05: Sleeping Dirty NIF

**Theme:** A -- Scheduler Blocking  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E04, E06

## Hypothesis
A DirtyIo-scheduled NIF sleeping 60 s does NOT starve normal schedulers. Normal-scheduler latency stays <= 5ms even during the sleep.

## Background
DirtyIo schedulers are a separate thread pool for blocking I/O NIFs. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF: `Lab.Native.sleep_for_ms_dirty_io/1` (DirtyIo-scheduled)
- Duration: 60 000ms default

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| `duration_ms` | 60_000 | 1_000-120_000 | match E04 for comparison |

## Execution
- CLI: `scripts/run_experiment.sh E05`
- UI: Catalog -> E05 -> Run
- Test: `mix test experiments/E05_sleeping_dirty_nif/`

## Expected Outcome
- Normal scheduler utilisation <= 5%
- Latency p99 <= 5ms during sleep

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/02_nif_taxonomy_rustler.md
- E04 (normal variant)
