# E07: Filesystem Stall (Normal vs DirtyIo)

**Theme:** A -- Scheduler Blocking  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E04, E05, E06

## Hypothesis
Reading a large file in a Normal NIF stalls the BEAM scheduler for the I/O duration; the same read in a DirtyIo NIF has no measurable impact on normal-scheduler latency.

## Background
Filesystem reads can block for tens of milliseconds on a cold cache. Done in a Normal NIF this freezes the scheduler. On a DirtyIo scheduler only that thread is stalled. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF (dirty): `Lab.Native.fs_read_bytes_dirty_io/1`
- Read size: 256 MiB from /dev/zero

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| `mb` | 256 | 1-512 | larger read = longer stall window |

## Execution
- CLI: `scripts/run_experiment.sh E07`
- UI: Catalog -> E07 -> Run
- Test: `mix test experiments/E07_filesystem_stall/`

## Expected Outcome
- Dirty variant: latency p99 <= 10ms during read

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/02_nif_taxonomy_rustler.md
- E06 (network wait analogue)
