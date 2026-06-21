# E09: Native Memory Leak (mem::forget)

**Theme:** B -- Failure Modes  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E10

## Hypothesis
Repeated calls to a NIF that allocates memory with mem::forget cause monotonically growing RSS, without the Erlang GC being aware of the leak.

## Background
mem::forget prevents Rust's Drop from running, leaving the allocation on the heap indefinitely. The Erlang GC cannot see native heap. RSS grows without any GC signal. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF: Lab.Native.leak_memory_mb/1
- Calls: 10 iterations x 100 MiB = 1 GiB total leak
- SystemProbe observes RSS every 500ms

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| mb | 100 | 1-500 | MiB leaked per NIF call |
| iterations | 10 | 1-50 | number of calls |

## Execution
- CLI: scripts/run_experiment.sh E09
- Test: mix test experiments/E09_memory_leak/

## Expected Outcome
- RSS grows by approximately mb x iterations MiB
- No Erlang GC events triggered by the leak

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/02_nif_taxonomy_rustler.md
- E10 (ResourceArc GC -- contrast)
