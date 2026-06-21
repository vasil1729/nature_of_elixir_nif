# 11 — Commit Convention

This lab uses **Conventional Commits** with a scope and a detailed body. Every
commit tells a reader *what* changed and *why* — so `git log` reads as the
lab's narrative.

## Format

```
type(scope): subject

body — what changed + why, wrapped at 72 chars.
       Reference experiment IDs, ADRs, related commits.

footer — run instructions, related links
```

- **Subject**: imperative mood, lowercase, no period, ≤ 72 chars
- **Body**: wrapped at 72 chars; explain *what* and *why*, not just *what*;
  reference experiment IDs (`E02`), ADRs (`ADR 0001`), related commits
- **Footer**: run instructions (`Run:`, `UI:`, `Test:`) and related links

## Types

| Type | Use for |
|------|---------|
| `plan` | PLAN.md changes, progress updates |
| `docs` | Documentation only |
| `infra` | Docker, scripts, config, CI — no app code |
| `feat` | New application functionality (lab_core, lab_native, lab_web, ...) |
| `test` | New or updated experiment tests |
| `refactor` | Code restructuring without behavior change |
| `chore` | Maintenance, deps, formatting |
| `fix` | Bug fix |

## Scopes

| Scope | Use for |
|-------|---------|
| `plan` | PLAN.md |
| `docs` | docs/ |
| `docker` | docker/ |
| `lab-core` | umbrella/apps/lab_core |
| `lab-native` | umbrella/apps/lab_native |
| `lab-port` | umbrella/apps/lab_port |
| `lab-web` | umbrella/apps/lab_web |
| `lab-runner` | umbrella/apps/lab_runner |
| `scripts` | scripts/ |
| `ci` | .github/ |
| `e01`–`e21` | Per-experiment commits |
| `report` | reports/ |

## Examples

### Experiment commit

```
test(e02): CPU-bound Dirty NIF — verify normal schedulers stay free

Hypothesis: a 30s DirtyCpu-scheduled NIF leaves normal schedulers
unblocked; latency stays near idle while one dirty scheduler hits
~100% utilization. This is the dirty-scheduler counterpart to E01.

Adds:
- lab_native: cpu_work_ms_dirty/1 (DirtyCpu variant of E01's NIF)
- experiments/E02_cpu_dirty_nif/: README, config.exs, e02_test.exs
- Thresholds (config.exs):
    normal_sched_util_max: 30
    latency_p99_max_ms: 50
    dirty_sched_util_min: 90
    vm_alive: true

The test asserts all four thresholds after running the workload
under lab_core instrumentation. Failure means BEAM's dirty/normal
scheduler independence is weaker than assumed.

Related: E01 (normal counterpart), E19 (saturation curve).
Theme A — Scheduler Blocking.
ADR: docs/adr/0001_one_native_crate.md (NIF variant pattern)

Run:    scripts/run_experiment.sh E02
UI:     Catalog → E02 → Run
Test:   mix test experiments/E02_cpu_dirty_nif/
```

### Infrastructure commit

```
infra(lab-native): scaffold Rustler crate with cpu_work Normal+DirtyCpu

Establishes the one-crate-many-NIFs pattern (ADR 0001): a single
Rustler crate exposes every NIF used across all 21 experiments,
each with Normal and Dirty variants via schedule flags. This
avoids 21 redundant crates and keeps the Rust→BEAM boundary in
one auditable place.

Adds:
- umbrella/apps/lab_native/: Cargo.toml, lib.rs, NIF loader
- cpu_work_ms/1 (Normal) + cpu_work_ms_dirty/1 (DirtyCpu)
- hello/0 smoke-test NIF
- Rust 1.92, Rustler 0.38

Build integration in Dockerfile.elixir_rust (stage 1: cargo build;
stage 2: copy .so into Elixir image).

ADR: docs/adr/0001_one_native_crate.md
```

### Docs commit

```
docs: BEAM scheduler model + NIF taxonomy deep-dive

Explains the mechanisms the experiments probe, so conclusions are
readable without prior BEAM internals knowledge.

docs/01_beam_scheduler_model.md:
- Reduction-budget preemption; why normal NIFs can't be preempted
- Async thread pool vs dirty schedulers (DirtyCpu/DirtyIo split)
- +S/+SDcpu/+SDio flag semantics; scheduler_wall_time math
- Links to E01/E03/E19 as live demonstrations

docs/02_nif_taxonomy_rustler.md:
- Four NIF scheduling classes (Normal/DirtyCpu/DirtyIo/None)
- Rustler's #[nif] macro expansion; Env lifetime trick
- Panic → RustlerError catch path; what crosses the C boundary
- What Rustler cannot catch (segfault, abort) — see E14
- Resource types, finalizers, ResourceArc — see E10

These docs are starting points, not authorities. Every claim they
make about behavior is verified by a linked experiment.
```

### Plan update (amend-only, for progress)

Progress updates are included in the *same commit* as the work they document,
not separate commits. Update PLAN.md's Progress section + "Currently
executing" line as part of every commit.

## Rules

1. **One logical change per commit.** Don't mix an experiment with an
   unrelated refactor.
2. **Every commit body explains why.** "Added X" is not enough. Why does X
   exist? What hypothesis does it test? What ADR does it follow?
3. **Reference experiment IDs and ADRs** where relevant.
4. **Include run instructions** in the footer for any commit that adds
   runnable code or tests.
5. **Update PLAN.md's Progress section** in the same commit.
6. **Never commit secrets.** This is a research lab, but still.
7. **Never use `--amend` or force-push** unless explicitly requested.
