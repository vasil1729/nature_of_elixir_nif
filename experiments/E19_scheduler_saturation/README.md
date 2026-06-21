# E19: Scheduler Saturation Curve (1 to 64 jobs)

**Theme:** D -- Scale  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E01, E02

## Hypothesis
With Normal NIFs, throughput scales linearly up to the number of schedulers, then plateaus due to scheduler saturation. With DirtyCpu NIFs, throughput scales linearly without impacting normal-scheduler latency.

## Background
At concurrency <= scheduler count, each NIF gets its own scheduler thread. Beyond that, NIFs queue. Dirty schedulers prevent this interference with normal Erlang concurrency. See docs/01_beam_scheduler_model.md.

## Setup
- NIF: Lab.Native.cpu_work_ms/1 (Normal) and Lab.Native.cpu_work_ms_dirty/1 (DirtyCpu)
- Job counts: 1, 2, 4, 8, 16, 32, 64
- Duration per job: 1 000ms

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| concurrency | 8 | 1-64 | number of concurrent NIF calls |
| duration_ms | 1_000 | 100-5_000 | duration per NIF call |

## Execution
- CLI: scripts/run_experiment.sh E19
- Test: mix test experiments/E19_scheduler_saturation/

## Expected Outcome
- Normal NIFs: throughput plateaus at ~4 (scheduler count)
- Dirty NIFs: latency stays low regardless of concurrency

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis with saturation point]

## References
- docs/01_beam_scheduler_model.md
- E01, E02
