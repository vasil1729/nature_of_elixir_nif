# E18: Large Binary Transfer (10MB to 1GB)

**Theme:** D -- Scale  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E19

## Hypothesis
Transferring large binaries across the NIF boundary incurs copy overhead proportional to size. RSS grows proportionally during the call, then GC recovers the allocation.

## Background
Erlang's binary heap is separate from the native heap. When a NIF returns a binary, the data is copied into an OwnedBinary and exposed as a term. This experiment measures the copy cost for various sizes. See docs/03_measurement_protocol.md.

## Setup
- NIF: Lab.Native.large_binary_mb/1
- Sizes: 10, 100, 256, 512, 1024 MiB
- Measures: wall time per call, RSS delta

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| mb | 100 | 10-1_024 | binary size in MiB |

## Execution
- CLI: scripts/run_experiment.sh E18
- Test: mix test experiments/E18_large_binary/

## Expected Outcome
- RSS grows by approximately mb MiB during the call
- Transfer time grows linearly with mb
- GC recovers the allocation after the call

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis with transfer-time numbers]

## References
- docs/03_measurement_protocol.md
- E09 (memory leak contrast)
