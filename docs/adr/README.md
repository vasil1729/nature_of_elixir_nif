# Architecture Decision Records

ADRs record *why* each architectural choice was made. They are committed
alongside the implementation they document and amended into
[../PLAN.md](../PLAN.md)'s Locked Decisions table.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001_one_native_crate.md) | One Rustler crate, one port binary | Accepted |
| [0002](0002_isolated_child_beam_for_crashes.md) | Isolated child BEAM for crash experiments | Accepted |
| [0003](0003_liveview_over_grafana.md) | LiveView UI over Grafana | Accepted |
| [0004](0004_strict_threshold_assertions.md) | Strict threshold assertions | Accepted |
| [0005](0005_docker_first_execution.md) | Docker-first execution | Accepted |
| [0006](0006_real_stack_postgres_oban.md) | Real stack: Postgres + Oban + Ecto | Accepted |
| [0007](0007_pdfium_for_pdf_workload.md) | pdfium-render for PDF workload | Accepted |
| [0008](0008_ui_primary_cli_for_ci.md) | UI primary, CLI for CI | Accepted |

## How to write a new ADR

1. Copy `0000_template.md` (to be added) or follow the format below.
2. Number sequentially (next: 0009).
3. File name: `NNNN_short_snake_case_title.md`.
4. Structure:
   - **Title** — one line
   - **Status** — Proposed / Accepted / Deprecated / Superseded
   - **Context** — what problem are we solving? what forces are in play?
   - **Decision** — what we chose
   - **Consequences** — what follows from this choice (positive + negative)
   - **Revisited** — leave empty until revisited; then record the date and
     outcome
5. Amend [../PLAN.md](../PLAN.md)'s Locked Decisions table with the new ADR.
6. Do not contradict existing ADRs. If a new decision supersedes an old one,
   mark the old ADR **Superseded by ADR NNNN** and write the new one.

## Principles

- **Context matters.** Record the forces that drove the decision, not just the
  outcome. A future reader needs to know *why*, not just *what*.
- **Consequences are honest.** Record negatives as well as positives. ADRs
  that only list upsides are propaganda.
- **Decisions are reversible.** If a decision is superseded, mark it — don't
  delete it. The history of *why we changed* is as valuable as the change.
