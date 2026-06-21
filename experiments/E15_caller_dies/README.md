# E15: Caller Dies Mid-Execution

**Theme:** C -- Lifecycle  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E16, E17

## Hypothesis
If an Elixir process that called a NIF is killed (via Process.exit/2) while the NIF is still executing, the NIF continues to completion. The BEAM does not interrupt running NIFs.

## Background
The BEAM has no mechanism to preempt a running NIF mid-execution. Process.exit marks the process for termination, but the NIF runs to completion on the scheduler thread. See docs/01_beam_scheduler_model.md.

## Setup
- NIF: Lab.Native.cpu_work_ms/1 (Normal, 5 000ms)
- Caller process is killed after 100ms

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| duration_ms | 5_000 | 1_000-30_000 | NIF run time |
| kill_after_ms | 100 | 10-1_000 | when to kill the caller |

## Execution
- CLI: scripts/run_experiment.sh E15
- Test: mix test experiments/E15_caller_dies/

## Expected Outcome
- The NIF runs for approximately 5 000ms despite the caller being killed at 100ms
- Scheduler utilisation remains high for the full NIF duration
- No BEAM crash

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/01_beam_scheduler_model.md
- E16 (node shutdown during work)
