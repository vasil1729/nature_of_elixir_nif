# E01: CPU-bound Normal NIF

**Theme:** A — Scheduler Blocking  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E02, E19

## Hypothesis
A Normal-scheduled NIF running CPU-bound work for ≥100ms will starve all Elixir processes sharing its scheduler, driving normal-scheduler utilisation above 90% and run-queue depth above 3.

## Background
Normal NIFs execute on the same thread as the BEAM scheduler that dispatched them. The scheduler cannot context-switch while the NIF is running. Any work over ~1ms degrades responsiveness for all processes on that scheduler. See docs/01_beam_scheduler_model.md.

## Setup
- NIF: `Lab.Native.cpu_work_ms/1` (Normal-scheduled)
- Duration: 30 000ms (parameterisable 100-60 000ms)
- Concurrent load: 4 tasks, one per scheduler (+S 4:4 in Docker)
- Sampler: 100ms  |  LatencyProbe: 10ms

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| `duration_ms` | 30 000 | 100-60 000 | longer = more starvation evidence |

## Execution
- CLI: `scripts/run_experiment.sh E01`
- UI: Catalog -> E01 -> Run
- Test: `mix test experiments/E01_cpu_normal_nif/`

## Expected Outcome
- Normal scheduler utilisation >= 90% for the run duration
- Run-queue depth >= 3 (backlog of Elixir processes)
- Latency p99 >= 200ms (Elixir processes starved)

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis with numbers]

## References
- docs/01_beam_scheduler_model.md (starting reference, verified by this experiment)
- E02 (dirty variant)
