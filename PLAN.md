# PLAN.md — Source of Truth

> **This document is the authoritative plan for the BEAM Characterization Lab.**
> If any other file, doc, or code conflicts with it, **this document wins**.
> Update it with every commit (see [Progress](#progress)).
> ADRs amend it; do not contradict it.

---

## Start Here

This lab is a controlled research environment that demonstrates, measures,
and documents the runtime behavior of Elixir, Rustler NIFs, Dirty NIFs, Ports,
and external processes under failure and stress conditions.

The goal is **not** to build production code. The goal is to **experimentally
verify assumptions about BEAM behavior through controlled failures.** Every
experiment is executable independently and produces measurable evidence.

The paradigm is **Jepsen-style characterization tests**: each experiment is an
ExUnit test with strict threshold assertions, runnable headless (CI) or
interactively (Phoenix LiveView UI). Every conclusion cites a passing test and
recorded metrics — no folklore, no blog posts, no documentation-alone claims.

Two execution front-ends share one foundation:
- **LiveView control room** (`docker compose up` → `localhost:4000`) — primary,
  interactive: browse experiments, tune parameters, watch the BEAM misbehave
  in real time, compare runs, read reports in-browser.
- **CLI / CI** (`scripts/run_experiment.sh E##`, `mix test --only slow`) —
  headless, reproducible, runs in GitHub Actions.

---

## Locked Decisions

| # | Decision | Choice | ADR |
|---|----------|--------|-----|
| 1 | Execution environment | Docker-first; `--local` host fallback | [ADR 0005](docs/adr/0005_docker_first_execution.md) |
| 2 | Scope | All 21 experiments, full measurement | — (scope) |
| 3 | Real-world stack | Postgres + Oban + Ecto; `pdfium-render` + libpdfium; `ring` for signing | [ADR 0006](docs/adr/0006_real_stack_postgres_oban.md), [ADR 0007](docs/adr/0007_pdfium_for_pdf_workload.md) |
| 4 | Assertion strictness | Strict numeric thresholds per hypothesis | [ADR 0004](docs/adr/0004_strict_threshold_assertions.md) |
| 5 | Reproduction surface | Docker + GitHub Actions CI; pinned versions | — (reproducibility) |
| 6 | Visualization | LiveView UI replaces Grafana; no prom/grafana services | [ADR 0003](docs/adr/0003_liveview_over_grafana.md) |
| 7 | Primary interface | UI primary (`docker compose up` → `:4000`); CLI for CI only | [ADR 0008](docs/adr/0008_ui_primary_cli_for_ci.md) |
| 8 | Crash experiment UX | Isolated child BEAM, streamed back to alive UI | [ADR 0002](docs/adr/0002_isolated_child_beam_for_crashes.md) |
| 9 | Native code layout | One Rustler crate, one port binary; many NIFs each | [ADR 0001](docs/adr/0001_one_native_crate.md) |

---

## Architecture (summary)

> Full detail in [docs/09_architecture.md](docs/09_architecture.md).

```
docker compose up  →  Phoenix LiveView at localhost:4000
                        │
           ┌────────────┼─────────────────────────────┐
           ▼            ▼                               ▼
     Dashboard     Experiment Run              Report Viewer
  (live metrics)  (params → launch → watch)    (markdown rendered)
                        │
              ┌─────────┴──────────┐
              ▼                    ▼
        :in_process            :isolated
     (non-crash exps)      (crash exps: E03,E08,
     runs in UI's BEAM      E11,E14,E16 → child BEAM
     UI may freeze =        via System.cmd, stdout
     EVIDENCE)              streamed back, UI survives
              │                    │
              ▼                    ▼
         lab_core (Sampler / LatencyProbe / SystemProbe / Reporter)
              │
         ┌────┴────┐
         ▼         ▼
    lab_native   lab_port
   (Rustler)    (Rust binary)
```

### Compose services

| Service | Purpose |
|---------|---------|
| `lab` | Elixir 1.18 + OTP 28 + Rust 1.92 + Rustler 0.38; serves Phoenix on `:4000`; contains `lab_native` + `lab_port` + all umbrella apps |
| `postgres` | Oban/Ecto job queue (E20) + run history storage (UI) |

### Repository structure

```
lab/
├── AGENTS.md                      # entry point for agents — read PLAN.md first
├── PLAN.md                        # THIS FILE — source of truth
├── README.md                      # thin entry: mission + quickstart
├── docs/
│   ├── INDEX.md                  # index of all docs
│   ├── 00_charter.md             # mission + evidence-over-folklore principles
│   ├── 01_beam_scheduler_model.md
│   ├── 02_nif_taxonomy_rustler.md
│   ├── 03_measurement_protocol.md
│   ├── 04_experiment_catalog.md
│   ├── 05_safety_isolation.md
│   ├── 06_reproducibility_protocol.md
│   ├── 07_ui_architecture.md
│   ├── 08_final_report_rubric.md
│   ├── 09_architecture.md
│   ├── 10_development_guide.md
│   ├── 11_commit_convention.md
│   ├── 12_glossary.md
│   ├── 13_runbook.md
│   └── adr/
│       ├── README.md             # ADR index + how to write new ones
│       └── 0001-0008             # decision records
├── umbrella/
│   ├── apps/
│   │   ├── lab_core/             # instrumentation + telemetry broadcast
│   │   ├── lab_native/           # ONE Rustler crate, many NIFs
│   │   ├── lab_port/             # ONE Rust port binary
│   │   ├── lab_runner/           # CLI for CI/headless
│   │   └── lab_web/              # Phoenix LiveView portal
│   │       ├── lib/lab_web/
│   │       │   ├── live/         # DashboardLive, CatalogLive, RunLive,
│   │       │   │                   HistoryLive, ReportLive, DocsLive
│   │       │   ├── components/   # SchedulerBar, LatencyChart, MetricCard, ...
│   │       │   ├── executor/     # InProcess + Isolated runners
│   │       │   └── telemetry_pub.ex
│   │       └── priv/static/
│   └── mix.exs
├── experiments/
│   └── E##_*/                    # one per experiment
│       ├── README.md             # hypothesis, setup, expected, actual
│       ├── config.exs            # thresholds + params schema + mode
│       ├── e##_test.exs          # ExUnit test with assertions
│       ├── report.md             # generated post-run
│       └── results/              # last run JSONL (gitignored)
├── scripts/                      # build_all, enter_lab, run_experiment, ...
├── docker/                       # Dockerfile, compose, entrypoint
├── .github/workflows/lab.yml     # CI matrix
├── reports/                      # aggregated final report + charts
└── data/                         # captured metrics (gitignored)
```

---

## Experiments

21 experiments merged from two source prompts, non-redundant. Each is an ExUnit
test with strict threshold assertions.

| ID | Experiment | Mode | Tags | Theme | Source |
|----|-----------|------|------|-------|--------|
| E01 | CPU-bound Normal NIF (100ms→60s) | in_process | @slow | A — Scheduler Blocking | ①01 + ②LR-01 |
| E02 | CPU-bound Dirty NIF (same) | in_process | @slow | A | ①02 + ②LR-02 |
| E03 | Infinite Loop (Normal vs Dirty) | **isolated** | @crash @slow | A | ①03 |
| E04 | Sleeping Normal NIF (60s) | in_process | @slow | A | ①09 + ②LR-03 |
| E05 | Sleeping Dirty NIF | in_process | @slow | A | ①09 + ②LR-04 |
| E06 | Network Wait (Normal vs DirtyIo) | in_process | @slow | A | ①09 + ②LR-05 |
| E07 | Filesystem Stall (Normal vs DirtyIo) | in_process | @slow | A | ①09 + ②LR-06 |
| E08 | Rust Panic (Rustler catch semantics) | **isolated** | @crash | B — Failure Modes | ①05 |
| E09 | Native Memory Leak (`mem::forget`) | in_process | @slow | B | ①04 + ②LR-11 |
| E10 | Resource Leak (`ResourceArc`) | in_process | @slow | B | ①11 |
| E11 | Mutex Deadlock | **isolated** | @crash @slow | B | ①06 |
| E12 | Thread Explosion (10→10k) | in_process | @slow | B | ①07 |
| E13 | Detached Native Thread lifecycle | in_process | @slow | B | ②LR-12 |
| E14 | Native Library Failure (segfault) | **isolated** | @crash | B | ①13 |
| E15 | Caller Dies Mid-Execution | in_process | @slow | C — Lifecycle | ②LR-07 |
| E16 | Node Shutdown During Native Work | **isolated** | @crash @slow | C | ②LR-08 |
| E17 | Port vs NIF vs Dirty (crash isolation) | in_process | @slow | C | ①12 + ②LR-13 |
| E18 | Large Binary Transfer (10MB→1GB) | in_process | @slow | D — Scale | ①08 |
| E19 | Scheduler Saturation Curve (1→64 jobs) | in_process | @slow | D | ①10 + ②LR-09 |
| E20 | Oban Interaction (100×30s jobs) | in_process | @slow @oban | E — Real-World | ②LR-10 |
| E21 | Real PDF Workload (1000 concurrent) | in_process | @slow @oban @pdf | E | ①14 + ②LR-14 |

### Shared native crate — `lab_native`

ONE Rustler crate exposes every NIF. Each has Normal + Dirty variants via
schedule flags.

| NIF | Experiments | Variants |
|-----|-------------|----------|
| `cpu_work_ms(ms)` | E01, E02, E19, E20 | Normal, DirtyCpu |
| `sleep_for_ms(ms)` | E04, E05, E06 | Normal, DirtyIo |
| `infinite_loop()` | E03 | Normal, DirtyCpu |
| `panic_now()` | E08 | Normal |
| `leak_memory_mb(mb)` | E09 | Normal |
| `make_resource(mb)` | E10 | Normal |
| `deadlock()` | E11 | DirtyCpu |
| `spawn_threads(n)` | E12 | Normal |
| `detach_thread(seconds)` | E13 | Normal |
| `segfault()` | E14 | Normal |
| `large_binary_mb(mb)` | E18 | Normal |
| `pdf_work(file, op)` | E21 | Normal, DirtyCpu |

### Shared port binary — `lab_port`

ONE Rust binary, stdin/stdout JSON protocol:
`{"cmd":"cpu_work","ms":30000}` → `{"ok":true,"duration_ms":30001}`.
Used by E17 (crash isolation) and E21 (PDF Port arm).
Intentional crash: `{"cmd":"segfault"}`.

---

## Execution Roadmap

~39 commits across 5 phases. Each commit follows
[docs/11_commit_convention.md](docs/11_commit_convention.md).

### Phase 0 — Foundation (3 commits)

1. **Meta-scaffold:** AGENTS.md + PLAN.md + thin README + docs/INDEX + docs/00
   charter + docs/11 commit convention + docs/12 glossary + docs/adr/README
2. **Mechanism deep-dives:** docs/01 beam scheduler model + docs/02 nif
   taxonomy + docs/03 measurement protocol + docs/04 catalog + docs/05 safety
   + docs/06 reproducibility + docs/07 ui arch + docs/08 final report rubric
3. **Architecture + dev guide:** docs/09 architecture + docs/10 dev guide +
   docs/13 runbook + ADRs 0001-0008

### Phase 1 — Infrastructure (9 commits)

4. `docker/` — Dockerfile.elixir_rust (multi-stage), docker-compose.yml
   (lab + postgres), entrypoint.sh
5. Elixir umbrella scaffold — mix.exs, config, formatter, .tool-versions
6. `lab_core` — Sampler, LatencyProbe, SystemProbe, Watchdog, telemetry_pub,
   Reporter
7. `lab_native` Rustler crate — build, load, hello, cpu_work_ms (Normal +
   DirtyCpu) — establishes one-crate-many-NIFs pattern
8. `lab_port` Rust binary — stdin/stdout JSON protocol, cpu_work command
9. `lab_web` Phoenix LiveView scaffold — endpoint, router, layout, core
   components (SchedulerBar, MetricCard, LatencyChart)
10. `lab_runner` CLI — headless experiment dispatch for CI
11. `scripts/` — build_all, enter_lab, run_experiment, collect_metrics,
    generate_report
12. `.github/workflows/lab.yml` — CI matrix, mix test --only slow, upload
    metrics artifact

### Phase 2 — UI + Harness (4 commits)

13. `lab_web` DashboardLive — real-time BEAM health
14. `lab_web` CatalogLive + RunLive — experiment browser + parameter form +
    live run execution
15. `lab_web` executor (InProcess + Isolated) + HistoryLive + ReportLive +
    DocsLive
16. ExUnit test template + threshold assertion helpers + Reporter integration

### Phase 3 — Experiments (21 commits)

17–37. E01→E21. One commit per experiment. Each adds any new NIF/port command
to `lab_native`/`lab_port`, adds `experiments/E##_*/{README.md, config.exs,
e##_test.exs}`, verifies via `scripts/run_experiment.sh E##` or UI.

### Phase 4 — Aggregation (2 commits)

38. `docs/04_experiment_catalog.md` filled + `reports/charts/`
39. `reports/FINAL_REPORT.md` — answers the 14 questions, each citing
    experiment IDs + passing tests + recorded metrics

---

## Progress

> Updated with every commit.

- [x] **Phase 0 commit 1:** Meta-scaffold (AGENTS.md, PLAN.md, README, docs/INDEX, docs/00, docs/11, docs/12, docs/adr/README)
- [x] **Phase 0 commit 2:** Mechanism deep-dives (docs/01–08)
- [x] **Phase 0 commit 3:** Architecture + dev guide + ADRs (docs/09, 10, 13, adr/0001–0008)
- [x] **Phase 1 commit 4:** docker/
- [x] **Phase 1 commit 5:** Elixir umbrella scaffold
- [ ] **Phase 1 commit 6:** lab_core instrumentation
- [ ] **Phase 1 commit 7:** lab_native Rustler crate
- [ ] **Phase 1 commit 8:** lab_port Rust binary
- [ ] **Phase 1 commit 9:** lab_web Phoenix LiveView scaffold
- [ ] **Phase 1 commit 10:** lab_runner CLI
- [ ] **Phase 1 commit 11:** scripts/
- [ ] **Phase 1 commit 12:** CI workflow
- [ ] **Phase 2 commit 13:** DashboardLive
- [ ] **Phase 2 commit 14:** CatalogLive + RunLive
- [ ] **Phase 2 commit 15:** executor + HistoryLive + ReportLive + DocsLive
- [ ] **Phase 2 commit 16:** ExUnit template + assertion helpers
- [ ] **Phase 3 commits 17–37:** Experiments E01–E21
- [ ] **Phase 4 commit 38:** Catalog filled + charts
- [ ] **Phase 4 commit 39:** FINAL_REPORT.md

**Currently executing:** Phase 1 commit 6 — lab_core instrumentation

---

## How to Resume

For any agent (human or automated) picking up mid-execution:

1. Read this section + the [Progress](#progress) section above.
2. Run `git log --oneline -20` to confirm repo state matches Progress.
3. Continue from the next unchecked item in [Execution Roadmap](#execution-roadmap).
4. Follow [docs/11_commit_convention.md](docs/11_commit_convention.md) for the
   commit message format.
5. **Update the Progress section in the same commit** — mark the item done and
   move the "Currently executing" line to the next item.
6. If a new architectural decision is needed, write a new ADR in `docs/adr/`
   and amend the Locked Decisions table above. Do not contradict existing ADRs.
7. If an experiment's actual outcome differs from its hypothesis, record both
   in the experiment's `README.md` and `report.md`. Do not "fix" the hypothesis
   to match — the discrepancy is the finding.

---

## References

| Document | Purpose |
|----------|---------|
| [docs/INDEX.md](docs/INDEX.md) | Index of all docs |
| [docs/00_charter.md](docs/00_charter.md) | Mission + evidence-over-folklore principles |
| [docs/01_beam_scheduler_model.md](docs/01_beam_scheduler_model.md) | How BEAM schedulers work |
| [docs/02_nif_taxonomy_rustler.md](docs/02_nif_taxonomy_rustler.md) | NIF kinds + Rustler internals |
| [docs/03_measurement_protocol.md](docs/03_measurement_protocol.md) | What we measure, how, units |
| [docs/04_experiment_catalog.md](docs/04_experiment_catalog.md) | All 21 experiments at a glance |
| [docs/05_safety_isolation.md](docs/05_safety_isolation.md) | What's dangerous, how Docker contains it |
| [docs/06_reproducibility_protocol.md](docs/06_reproducibility_protocol.md) | Assertions, CI, golden baselines |
| [docs/07_ui_architecture.md](docs/07_ui_architecture.md) | LiveView design, execution modes |
| [docs/08_final_report_rubric.md](docs/08_final_report_rubric.md) | 14 questions, pre-linked to experiments |
| [docs/09_architecture.md](docs/09_architecture.md) | System architecture, diagrams, data flow |
| [docs/10_development_guide.md](docs/10_development_guide.md) | How to add an experiment, NIF, UI page |
| [docs/11_commit_convention.md](docs/11_commit_convention.md) | Commit format, types, scopes, templates |
| [docs/12_glossary.md](docs/12_glossary.md) | BEAM/NIF/Rustler/Oban/Port terms defined |
| [docs/13_runbook.md](docs/13_runbook.md) | Build, run, debug, troubleshoot |
| [docs/adr/](docs/adr/) | Architecture Decision Records |
