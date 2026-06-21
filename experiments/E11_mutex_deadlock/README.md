# E11: Mutex Deadlock

**Theme:** B -- Failure Modes  |  **Mode:** isolated  |  **Tags:** @crash @slow
**Related:** E12, E13

## Hypothesis
A NIF that creates a mutex deadlock on a DirtyCpu scheduler hangs indefinitely. The BEAM Watchdog detects the timeout and kills the isolated child BEAM.

## Background
Mutex deadlocks in native code are invisible to the Erlang runtime. The BEAM Watchdog detects the time budget being exceeded and kills the run. See docs/05_safety_isolation.md.

## Setup
- NIF: Lab.Native.deadlock/0 (DirtyCpu-scheduled)
- Mode: isolated child BEAM
- Watchdog timeout: 15 000ms

## Parameters
No parameters.

## Execution
- CLI: scripts/run_experiment.sh E11
- Test: mix test experiments/E11_mutex_deadlock/

## Expected Outcome
- Child BEAM hangs
- Watchdog fires after 15 s
- Exit code != 0

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/05_safety_isolation.md
- ADR 0002
