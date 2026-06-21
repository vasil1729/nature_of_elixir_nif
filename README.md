# BEAM Characterization Lab

A reproducible laboratory that demonstrates, measures, and documents how BEAM
behaves when native code runs for extended periods — under failure and stress
conditions.

**Every conclusion is backed by an executed experiment, a passing test, and
recorded metrics. No folklore. No blog-post authorities. No documentation-alone
claims.**

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

## Read PLAN.md first

**[PLAN.md](PLAN.md) is the source of truth** for this project: mission, locked
decisions, architecture, experiment catalog, execution roadmap, and a living
progress section. Start there.

See also [AGENTS.md](AGENTS.md) for working rules if you're an agent
(human or automated) contributing to this repo.

## What's inside

- **21 experiments** (E01–E21) spanning scheduler blocking, native failure
  modes, lifecycle & isolation, scale & transfer, and real-world workloads
- **Phoenix LiveView control room** — browse experiments, tune parameters,
  watch the BEAM misbehave in real time, compare runs, read reports
- **One Rustler crate** (`lab_native`) exposing every NIF with Normal and
  Dirty variants
- **One Rust port binary** (`lab_port`) for crash-isolation comparisons
- **Strict threshold assertions** — each experiment is an ExUnit test that
  passes or fails against its hypothesis
- **Docker + CI** — pinned versions, reproducible on any machine

## Documentation

See [docs/INDEX.md](docs/INDEX.md) for the full index. Key entries:

- [docs/01_beam_scheduler_model.md](docs/01_beam_scheduler_model.md) — how BEAM
  schedulers actually work
- [docs/02_nif_taxonomy_rustler.md](docs/02_nif_taxonomy_rustler.md) — NIF
  kinds and what Rustler does and doesn't protect against
- [docs/04_experiment_catalog.md](docs/04_experiment_catalog.md) — all 21
  experiments at a glance
- [docs/09_architecture.md](docs/09_architecture.md) — system architecture
- [docs/adr/](docs/adr/) — why each architectural choice was made

## License

This is a research artifact. Use it to learn, verify, and teach.
