# E13: Detached Native Thread Lifecycle

**Theme:** B -- Failure Modes  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E12

## Hypothesis
A NIF that spawns a detached OS thread and returns immediately does NOT notify the BEAM when the thread eventually exits. The thread runs independently; its exit is silent to all Erlang processes.

## Background
Detached OS threads are invisible to the Erlang runtime. The BEAM cannot receive signals from them. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF: Lab.Native.detach_thread/1
- Thread duration: 10 seconds

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| seconds | 10 | 1-60 | duration the detached thread lives |

## Execution
- CLI: scripts/run_experiment.sh E13
- Test: mix test experiments/E13_detached_thread/

## Expected Outcome
- NIF returns :ok immediately (< 1ms)
- Thread count +1 visible in /proc for ~10 s
- No Erlang message received

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/02_nif_taxonomy_rustler.md
- E12 (thread explosion)
