# AGENTS.md

This file is the entry point for any agent (human or automated) working on this repository.

## Read PLAN.md first

**`PLAN.md` is the source of truth for this project.** Read it before doing anything else. It contains:

- The mission and locked decisions
- The full architecture (summary) and experiment catalog
- The execution roadmap (~39 commits)
- A living **Progress** section showing what is done and what is next
- **How to Resume** instructions for picking up mid-execution

If `PLAN.md` conflicts with any other file, doc, or code, **`PLAN.md` wins**.

## Working rules

1. **Update `PLAN.md`'s Progress section in every commit.** Mark the completed item and move the "Currently executing" line.
2. **Follow `docs/11_commit_convention.md`** for commit message format. Every commit body explains *what* and *why*, references experiment IDs and ADRs where relevant, and includes run instructions.
3. **Architectural decisions go in `docs/adr/`** as new ADRs. A new ADR amends `PLAN.md`'s Locked Decisions table — do not contradict it.
4. **Every experiment is an ExUnit test** with strict threshold assertions, runnable via `scripts/run_experiment.sh E##` (headless/CI) or the LiveView UI at `localhost:4000` (interactive). See `docs/06_reproducibility_protocol.md`.
5. **No folklore.** Every conclusion in docs or reports must cite an experiment ID, a passing test, and recorded metrics. Documentation claims about BEAM behavior are *starting references* that experiments verify — not authorities.
6. **One Rustler crate, one port binary.** All NIFs live in `umbrella/apps/lab_native`; all port commands live in `umbrella/apps/lab_port`. See ADR 0001.
7. **Crash experiments run in an isolated child BEAM** so the UI survives. See ADR 0002.

## Quickstart

```bash
docker compose -f docker/docker-compose.yml up
# → Phoenix LiveView control room at http://localhost:4000
```

Headless / CI:

```bash
scripts/run_experiment.sh E02    # run one experiment
mix test --only slow             # run the full characterization suite
```

## Where things live

| Path | Role |
|------|------|
| `PLAN.md` | Source of truth — read first |
| `README.md` | Thin entry — points to PLAN.md + quickstart |
| `docs/` | Reference material (mechanism deep-dives, protocols, ADRs) |
| `docs/INDEX.md` | Index of all docs |
| `docs/adr/` | Architecture Decision Records — the "why" behind each choice |
| `umbrella/apps/lab_core/` | Instrumentation: Sampler, probes, Reporter, telemetry broadcast |
| `umbrella/apps/lab_native/` | Single Rustler crate exposing every NIF |
| `umbrella/apps/lab_port/` | Single Rust port binary |
| `umbrella/apps/lab_web/` | Phoenix LiveView control room |
| `umbrella/apps/lab_runner/` | CLI for CI/headless execution |
| `experiments/E##_*/` | One directory per experiment (README, config, test, report) |
| `scripts/` | Build, run, collect, report shell scripts |
| `docker/` | Dockerfile, compose, entrypoint |
| `reports/` | Aggregated final report + charts |
| `data/` | Captured metrics (gitignored) |
