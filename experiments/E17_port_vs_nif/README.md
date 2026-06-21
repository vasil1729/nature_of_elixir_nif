# E17: Port vs NIF vs Dirty (Crash Isolation)

**Theme:** C -- Lifecycle  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E08, E14

## Hypothesis
A segfault in a Port binary kills only the port process -- the calling BEAM process receives an exit signal and survives. The same segfault in a NIF (E14) kills the entire BEAM VM.

## Background
Ports run as separate OS processes. A crash in the port process sends an exit signal to the owning Elixir process, which can catch it. The BEAM itself is unaffected. This is the key isolation advantage of Ports over NIFs. See docs/09_architecture.md.

## Setup
- Port binary: lab_port with cpu_work command
- Reference: E14 demonstrates NIF segfault kills the VM

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| duration_ms | 1_000 | 100-10_000 | cpu_work duration |

## Execution
- CLI: scripts/run_experiment.sh E17
- Test: mix test experiments/E17_port_vs_nif/

## Expected Outcome
- Port cpu_work returns result, VM alive
- VM alive throughout

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis; cross-ref E14]

## References
- docs/09_architecture.md
- E14 (NIF segfault)
