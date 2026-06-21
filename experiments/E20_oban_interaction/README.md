# E20: Oban Interaction (100 x 30s jobs)

**Theme:** E -- Real-World  |  **Mode:** in_process  |  **Tags:** @slow @oban
**Related:** E21

## Hypothesis
Running 100 Oban jobs, each calling a 30s DirtyCpu NIF, does not degrade Oban's own internal concurrency (heartbeat, queue polling) or the Phoenix LiveView UI responsiveness.

## Background
Oban uses Postgres-backed job queues and relies on regular heartbeats to maintain job locks. If NIF work starves the BEAM, Oban jobs may fail their heartbeat. DirtyCpu scheduling isolates NIF work from Oban's Elixir concurrency. See docs/04_experiment_catalog.md.

## Setup
- NIF: Lab.Native.cpu_work_ms_dirty/1 (DirtyCpu, 30 000ms)
- Oban workers: 10 concurrent x 10 batches = 100 total jobs
- Postgres: required (compose service)

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| job_count | 100 | 10-500 | total Oban jobs |
| concurrency | 10 | 1-50 | Oban worker concurrency |
| duration_ms | 5_000 | 1_000-30_000 | per-job NIF duration |

## Execution
- CLI: scripts/run_experiment.sh E20
- Test: mix test --only oban experiments/E20_oban_interaction/
- Note: Requires Postgres (docker compose up)

## Expected Outcome
- All jobs complete without heartbeat failures
- VM alive throughout

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis]

## References
- docs/04_experiment_catalog.md
- E21 (PDF real-world extension)
