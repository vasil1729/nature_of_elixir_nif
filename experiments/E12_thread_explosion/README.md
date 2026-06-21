# E12: Thread Explosion (10 to 10k threads)

**Theme:** B -- Failure Modes  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E13

## Hypothesis
Spawning large numbers of OS threads from a NIF consumes OS resources and is visible to the OS thread counter, but the BEAM VM itself remains alive unless the OS thread limit is exceeded.

## Background
OS threads are scarce resources. Each thread consumes stack memory. The SystemProbe records thread count from /proc/self/status. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF: Lab.Native.spawn_threads/1
- Thread counts: 10, 100, 500, 1000
- SystemProbe: 500ms

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| count | 100 | 10-1000 | thread count |

## Execution
- CLI: scripts/run_experiment.sh E12
- Test: mix test experiments/E12_thread_explosion/

## Expected Outcome
- Thread count in /proc grows proportionally to count
- RSS grows by count x 8 MiB
- VM survives for <= 500 threads

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis with thread-count observations]

## References
- docs/02_nif_taxonomy_rustler.md
- E13 (detached thread lifecycle)
