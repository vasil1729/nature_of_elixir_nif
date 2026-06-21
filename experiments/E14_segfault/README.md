# E14: Native Library Failure (Segfault)

**Theme:** B -- Failure Modes  |  **Mode:** isolated  |  **Tags:** @crash
**Related:** E08

## Hypothesis
A segmentation fault inside a NIF kills the entire OS process -- the BEAM VM has no way to recover. The isolated child BEAM crashes; the UI (parent BEAM) survives.

## Background
Unlike a Rust panic (E08), a segfault triggers the OS SIGSEGV signal, which kills the entire process. There is no catch_unwind for hardware signals. The child BEAM isolation (ADR 0002) is the only safety mechanism. See docs/05_safety_isolation.md.

## Setup
- NIF: Lab.Native.segfault/0 (Normal-scheduled)
- Mode: isolated child BEAM (REQUIRED)
- Expected exit code: non-zero (SIGSEGV = 139 on Linux)

## Parameters
No parameters.

## Execution
- CLI: scripts/run_experiment.sh E14
- Test: mix test experiments/E14_segfault/

## Expected Outcome
- Isolated child BEAM process dies with non-zero exit code
- UI (parent BEAM) remains alive

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/05_safety_isolation.md
- ADR 0002
- E08 (Rust panic -- BEAM survives)
