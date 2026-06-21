# E16: Node Shutdown During Native Work

**Theme:** C -- Lifecycle  |  **Mode:** isolated  |  **Tags:** @crash @slow
**Related:** E15, E17

## Hypothesis
Initiating a graceful BEAM shutdown (System.stop/0) while a long-running NIF is executing eventually terminates the isolated child BEAM.

## Background
System.stop/0 sends the shutdown signal to OTP's application controller. The BEAM attempts a graceful shutdown, but if a scheduler thread is blocked in a NIF, the graceful shutdown may time out and fall back to halt. See docs/05_safety_isolation.md.

## Setup
- NIF: Lab.Native.cpu_work_ms/1 (Normal, 30 000ms)
- Shutdown triggered after 1 000ms
- Mode: isolated child BEAM

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| duration_ms | 30_000 | 5_000-120_000 | how long the NIF runs |
| shutdown_after_ms | 1_000 | 100-5_000 | when to call System.stop |

## Execution
- CLI: scripts/run_experiment.sh E16
- Test: mix test experiments/E16_node_shutdown/

## Expected Outcome
- Isolated BEAM goes down (non-zero exit)
- Parent UI BEAM is unaffected

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/05_safety_isolation.md
- ADR 0002
- E15 (caller dies)
