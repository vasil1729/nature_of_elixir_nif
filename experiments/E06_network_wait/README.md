# E06: Network Wait (Normal vs DirtyIo)

**Theme:** A -- Scheduler Blocking  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E04, E05, E07

## Hypothesis
Using a Normal NIF to simulate network wait (blocking sleep) degrades normal-scheduler latency, while a DirtyIo NIF performing the same wait keeps latency <= 5ms.

## Background
Network I/O blocks the OS thread. In a Normal NIF this freezes the BEAM scheduler. In a DirtyIo NIF only the dirty thread is blocked. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF (dirty): `Lab.Native.sleep_for_ms_dirty_io/1`
- Duration: 5 000ms simulated network latency

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| `duration_ms` | 5_000 | 100-30_000 | simulated network RTT |

## Execution
- CLI: `scripts/run_experiment.sh E06`
- UI: Catalog -> E06 -> Run
- Test: `mix test experiments/E06_network_wait/`

## Expected Outcome
- Dirty variant: run_queue <= 1, latency p99 <= 5ms

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/02_nif_taxonomy_rustler.md
- E04, E05
