# E02: CPU-bound Dirty NIF

**Theme:** A -- Scheduler Blocking  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E01, E19

## Hypothesis
A DirtyCpu-scheduled NIF running the same CPU-bound work leaves normal schedulers free, keeping run-queue depth <= 1 and latency p99 <= 50ms.

## Background
DirtyCpu NIFs are dispatched to a separate pool of dirty schedulers. Normal schedulers continue servicing Elixir processes uninterrupted. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF: `Lab.Native.cpu_work_ms_dirty/1` (DirtyCpu-scheduled)
- Duration: 30 000ms
- Concurrent load: 4 tasks

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| `duration_ms` | 30 000 | 100-60 000 | match E01 for direct comparison |

## Execution
- CLI: `scripts/run_experiment.sh E02`
- UI: Catalog -> E02 -> Run
- Test: `mix test experiments/E02_cpu_dirty_nif/`

## Expected Outcome
- Normal scheduler utilisation <= 20%
- Run-queue depth <= 1
- Latency p99 <= 50ms

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis with numbers; compare to E01]

## References
- docs/02_nif_taxonomy_rustler.md
- E01 (normal variant -- baseline)
