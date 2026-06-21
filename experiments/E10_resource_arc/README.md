# E10: Resource Leak (ResourceArc)

**Theme:** B -- Failure Modes  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E09

## Hypothesis
When a NIF allocates memory managed by a Rustler ResourceArc, the Erlang GC eventually frees the native memory when the term is collected -- in contrast to mem::forget (E09).

## Background
Rustler ResourceArc registers a destructor with the Erlang runtime. When the Erlang term is GC'd, BEAM calls the destructor. See docs/02_nif_taxonomy_rustler.md.

## Setup
- NIF: Lab.Native.make_resource/1 -- allocates and immediately drops
- 10 iterations x 100 MiB allocations

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| mb | 100 | 1-500 | allocation size per call |
| iterations | 10 | 1-50 | number of calls |

## Execution
- CLI: scripts/run_experiment.sh E10
- Test: mix test experiments/E10_resource_arc/

## Expected Outcome
- RSS does not grow monotonically (GC intervenes)
- RSS peak <= 2 x single allocation size
- VM survives

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis; compare to E09]

## References
- docs/02_nif_taxonomy_rustler.md
- E09 (mem::forget -- no GC recovery)
