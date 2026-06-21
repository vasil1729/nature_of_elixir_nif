# E21: Real PDF Workload (1000 concurrent renders)

**Theme:** E -- Real-World  |  **Mode:** in_process  |  **Tags:** @slow @oban @pdf
**Related:** E17, E20

## Hypothesis
Processing 1 000 concurrent PDF page renders via DirtyCpu NIFs completes within the time budget without degrading normal-scheduler latency, while the equivalent Port-based approach incurs higher per-request overhead.

## Background
This is the capstone experiment combining: dirty scheduling, large binary transfer, Oban job management, and crash isolation. We stub pdfium-render with cpu_work_impl for reproducibility. See docs/08_final_report_rubric.md.

## Setup
- NIF arm: Lab.Native.pdf_work_dirty/1 (DirtyCpu, simulated render time)
- Port arm: lab_port with pdf_work command
- Oban workers: 50 concurrent x 20 batches = 1 000 total renders

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|
| render_count | 1_000 | 100-5_000 | total PDF page renders |
| concurrency | 50 | 1-200 | concurrent renders |
| render_ms | 100 | 10-1_000 | simulated render time per page |
| backend | nif | nif/port | which execution arm |

## Execution
- CLI: scripts/run_experiment.sh E21
- Test: mix test --only pdf experiments/E21_pdf_workload/

## Expected Outcome
- NIF arm: <= 10% latency overhead vs sequential
- Port arm: higher per-call overhead but crash-safe
- VM alive throughout both arms

## Actual Outcome
[Filled after first run]

## Conclusion
[Answer hypothesis with numbers; NIF vs Port tradeoff]

## References
- docs/08_final_report_rubric.md
- E17 (port crash isolation)
- E20 (Oban integration)
