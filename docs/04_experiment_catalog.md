# 04 — Experiment Catalog

> All 21 experiments at a glance. Each is an ExUnit test with strict threshold
> assertions. This catalog is the cross-reference index used by the final
> report — every conclusion cites experiment IDs from this table.
>
> Status column is filled in as experiments land (Phase 3).

## Theme A — Scheduler Blocking

These experiments probe what blocks a normal scheduler vs what stays on dirty
schedulers. Core question: *what actually starves a scheduler?*

| ID | Name | NIF | Mode | Tags | Status |
|----|------|-----|------|------|--------|
| E01 | CPU-bound Normal NIF | `cpu_work_ms` (Normal) | in_process | @slow | pending |
| E02 | CPU-bound Dirty NIF | `cpu_work_ms_dirty` (DirtyCpu) | in_process | @slow | pending |
| E03 | Infinite Loop | `infinite_loop` (Normal+DirtyCpu) | isolated | @crash @slow | pending |
| E04 | Sleeping Normal NIF | `sleep_for_ms` (Normal) | in_process | @slow | pending |
| E05 | Sleeping Dirty NIF | `sleep_for_ms_dirty` (DirtyIo) | in_process | @slow | pending |
| E06 | Network Wait | `sleep_for_ms` + socket (Normal+DirtyIo) | in_process | @slow | pending |
| E07 | Filesystem Stall | `sleep_for_ms` + file (Normal+DirtyIo) | in_process | @slow | pending |

**Key comparisons:** E01 vs E02 (normal vs dirty CPU), E04 vs E05 (normal vs
dirty sleep), E06/E07 normal vs DirtyIo.

## Theme B — Native Failure Modes

These experiments probe what Rustler catches, what it doesn't, and what
happens to native resources and threads under failure.

| ID | Name | NIF | Mode | Tags | Status |
|----|------|-----|------|------|--------|
| E08 | Rust Panic | `panic_now` (Normal) | isolated | @crash | pending |
| E09 | Native Memory Leak | `leak_memory_mb` (Normal) | in_process | @slow | pending |
| E10 | Resource Leak | `make_resource` (Normal) | in_process | @slow | pending |
| E11 | Mutex Deadlock | `deadlock` (DirtyCpu) | isolated | @crash @slow | pending |
| E12 | Thread Explosion | `spawn_threads` (Normal) | in_process | @slow | pending |
| E13 | Detached Native Thread | `detach_thread` (Normal) | in_process | @slow | pending |
| E14 | Native Library Failure | `segfault` (Normal) | isolated | @crash | pending |

**Key comparisons:** E08 (caught) vs E14 (not caught); E09 (BEAM-blind leak)
vs E10 (BEAM-GC'd resource).

## Theme C — Lifecycle & Isolation

These experiments probe what survives caller death, process death, and node
shutdown — and what doesn't.

| ID | Name | NIF/Port | Mode | Tags | Status |
|----|------|----------|------|------|--------|
| E15 | Caller Dies Mid-Execution | `cpu_work_ms` | in_process | @slow | pending |
| E16 | Node Shutdown During Work | `cpu_work_ms` | isolated | @crash @slow | pending |
| E17 | Port vs NIF vs Dirty | `cpu_work` + `lab_port` | in_process | @slow | pending |

**Key comparison:** E17 is the canonical "which architecture survives a
crash?" comparison — NIF vs Dirty NIF vs Port, same workload, same crash.

## Theme D — Scale & Transfer

These experiments probe the practical limits of the NIF mechanism.

| ID | Name | NIF | Mode | Tags | Status |
|----|------|-----|------|------|--------|
| E18 | Large Binary Transfer | `large_binary_mb` (Normal) | in_process | @slow | pending |
| E19 | Scheduler Saturation Curve | `cpu_work_ms` (Normal+Dirty) | in_process | @slow | pending |

**Key outputs:** E18 produces a size-vs-time curve; E19 produces a
concurrency-vs-latency curve for both normal and dirty schedulers.

## Theme E — Real-World

These experiments use real libraries and workloads to bridge from synthetic
stress to something production-like.

| ID | Name | Stack | Mode | Tags | Status |
|----|------|-------|------|------|--------|
| E20 | Oban Interaction | Oban + Postgres + Ecto | in_process | @slow @oban | pending |
| E21 | Real PDF Workload | `pdfium-render` + Oban | in_process | @slow @oban @pdf | pending |

**Key comparison:** E21 compares NIF, Dirty NIF, and Port on a real PDF
workload at 1000 concurrent jobs — the closest to production of any experiment.

## Cross-reference matrix (which experiments answer which questions)

The final report's 14 questions each cite experiments from this matrix. See
[08_final_report_rubric.md](08_final_report_rubric.md) for the full mapping.

| Question | Primary experiments |
|----------|---------------------|
| What blocks a scheduler? | E01, E04, E06, E07 |
| What only blocks dirty schedulers? | E02, E05, E19 |
| What survives caller death? | E15 |
| What survives process death? | E17 |
| What survives node shutdown? | E16 |
| What causes scheduler starvation? | E01, E03, E19 |
| What causes dirty scheduler starvation? | E02, E19 |
| What causes memory exhaustion? | E09, E18 |
| What causes VM crashes? | E08, E14 |
| What Rustler solves | E08 vs E14 |
| What Rustler doesn't solve | E14, E11 |
| When is a Port superior? | E17 |
| When is a Dirty NIF superior? | E02 vs E01, E19 |
| Practical limits | E12, E18, E19 |

## Per-experiment deliverables (what each commit adds)

Every experiment commit produces:

```
experiments/E##_slug/
├── README.md          # hypothesis, background, setup, params, expected,
│                      #   actual (filled post-run), evidence, conclusion
├── config.exs         # params schema + thresholds + mode + tags
├── e##_test.exs       # ExUnit test: run workload, collect, assert
├── report.md          # generated by Reporter from data/E##/*.jsonl
└── results/           # last run's derived artifacts (gitignored)
```

Plus any new NIF/port command added to `lab_native`/`lab_port` in the same
commit.
