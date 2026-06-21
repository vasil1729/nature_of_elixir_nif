# Documentation Index

Reference material for the BEAM Characterization Lab. All docs are subordinate
to [../PLAN.md](../PLAN.md), which is the source of truth.

## Read order (for understanding the lab)

1. [00_charter.md](00_charter.md) — mission + evidence-over-folklore principles
2. [01_beam_scheduler_model.md](01_beam_scheduler_model.md) — how BEAM
   schedulers work (the mechanisms the experiments probe)
3. [02_nif_taxonomy_rustler.md](02_nif_taxonomy_rustler.md) — NIF kinds +
   Rustler internals (what it catches vs doesn't)
4. [03_measurement_protocol.md](03_measurement_protocol.md) — what we measure,
   how, units, tolerances
5. [04_experiment_catalog.md](04_experiment_catalog.md) — all 21 experiments
   at a glance, cross-reference matrix
6. [05_safety_isolation.md](05_safety_isolation.md) — what's dangerous, how
   Docker contains it
7. [06_reproducibility_protocol.md](06_reproducibility_protocol.md) —
   assertions, CI matrix, golden baselines
8. [07_ui_architecture.md](07_ui_architecture.md) — LiveView design, execution
   modes (in_process vs isolated)
9. [08_final_report_rubric.md](08_final_report_rubric.md) — the 14 questions
   the final report must answer, pre-linked to experiments

## Reference (consult as needed)

- [09_architecture.md](09_architecture.md) — system architecture, mermaid
  diagrams, data flow, Postgres schema, port protocol spec, telemetry pipeline
- [10_development_guide.md](10_development_guide.md) — how to add an
  experiment, NIF, UI page; conventions
- [11_commit_convention.md](11_commit_convention.md) — commit format, types,
  scopes, templates
- [12_glossary.md](12_glossary.md) — BEAM/NIF/Rustler/Oban/Port terms defined
- [13_runbook.md](13_runbook.md) — build, run, debug, troubleshoot, common
  failures

## Architecture Decision Records

The "why" behind each architectural choice. See [adr/README.md](adr/README.md)
for the index and how to write new ones.

| ADR | Title |
|-----|-------|
| [0001](adr/0001_one_native_crate.md) | One Rustler crate, one port binary |
| [0002](adr/0002_isolated_child_beam_for_crashes.md) | Isolated child BEAM for crash experiments |
| [0003](adr/0003_liveview_over_grafana.md) | LiveView UI over Grafana |
| [0004](adr/0004_strict_threshold_assertions.md) | Strict threshold assertions |
| [0005](adr/0005_docker_first_execution.md) | Docker-first execution |
| [0006](adr/0006_real_stack_postgres_oban.md) | Real stack: Postgres + Oban + Ecto |
| [0007](adr/0007_pdfium_for_pdf_workload.md) | pdfium-render for PDF workload |
| [0008](adr/0008_ui_primary_cli_for_ci.md) | UI primary, CLI for CI |

## Conventions

- Documentation claims about BEAM behavior are **starting references** that
  experiments verify — not authorities. Every such claim links to the
  experiment that verifies it.
- No conclusion in any doc may be based solely on documentation or assumptions.
  Cite an experiment ID, a passing test, and recorded metrics.
- ADRs are committed alongside the implementation they document.
- New ADRs amend [../PLAN.md](../PLAN.md)'s Locked Decisions table.
