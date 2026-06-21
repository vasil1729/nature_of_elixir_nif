# ADR 0001: One Rustler crate, one port binary

## Status

Accepted

## Context

The lab has 21 experiments, many of which need native code (NIFs or port
commands). A naive approach would create one Rustler crate per experiment
(or per concern), leading to ~15 crates with duplicated boilerplate
(`Cargo.toml`, NIF loader, build integration) and the Rust→BEAM boundary
spread across many places.

Two forces are in tension:
- **Auditability** wants the native boundary in one place, so reviewers can
  see every NIF the lab exposes at a glance.
- **Modularity** wants each experiment self-contained, with its own NIFs
  living alongside its Elixir code.

The lab is a research artifact, not a long-lived product. The auditability
force dominates: being able to enumerate every native function the BEAM can
call is more valuable than per-experiment modularity.

## Decision

**One Rustler crate** (`umbrella/apps/lab_native`) exposes every NIF used
across all 21 experiments. Each NIF has Normal and Dirty variants (where
applicable) via Rustler's `schedule` attribute.

**One Rust port binary** (`umbrella/apps/lab_port`) implements every port
command via a stdin/stdout JSON protocol.

When an experiment needs a new NIF, it adds the function to
`lab_native/native/src/lib.rs` (or a new module file imported there) and
registers it in the `rustler::init!` macro. The experiment's commit includes
both the NIF addition and the experiment directory.

## Consequences

**Positive:**
- One `Cargo.toml`, one build step, one `.so` to load — simpler Docker build
- The full set of native functions is enumerable in one file
- Shared utilities (timing, allocation helpers) live in one crate
- No per-experiment crate overhead

**Negative:**
- Every experiment commit touches the shared crate, creating merge conflicts
  if experiments are developed in parallel (not a concern for this lab's
  sequential execution)
- The crate grows large; `cargo build` recompiles more than necessary
- A bad NIF (e.g. E14's segfault) is in the same crate as innocent ones —
  but that's fine, we don't ship this

**Neutral:**
- NIF naming convention: `foo_bar/1` (Normal), `foo_bar_dirty/1` (DirtyCpu),
  `foo_bar_dirty_io/1` (DirtyIo). The schedule class is visible at the call
  site.

## Revisited

_(none yet)_
