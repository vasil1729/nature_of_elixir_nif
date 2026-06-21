# 12 — Glossary

Terms used throughout this lab, defined as they're used here. When a term has
a broader meaning elsewhere, we note the lab-specific sense.

## BEAM

**Bogdan's Erlang Abstract Machine** — the virtual machine that runs Erlang
and Elixir. Schedules processes across OS threads, manages garbage collection
per process, and provides the isolation guarantees this lab probes.

## Scheduler

An OS thread managed by BEAM that runs Erlang/Elixir processes. Each scheduler
executes one process at a time, switching between them via reduction-count
preemption. See [01_beam_scheduler_model.md](01_beam_scheduler_model.md).

- **Normal scheduler** — runs regular BEAM processes. Count set by `+S`.
- **Dirty scheduler** — runs long/native operations that can't be preempted.
  Two flavors: **DirtyCpu** (CPU-bound) and **DirtyIo** (I/O-bound). Count
  set by `+SDcpu` and `+SDio`.

## Reduction

A unit of work BEAM uses to schedule processes. Each process gets a budget
(~2000 reductions); when it runs out, the scheduler preempts and switches to
the next process. A NIF that doesn't call `enif_consume_timeslice` consumes
its budget in one C call and blocks the scheduler until it returns.

## NIF

**Native Implemented Function** — a function implemented in C (or Rust via
Rustler) called directly from Erlang/Elixir. Runs on a BEAM scheduler thread.
Not preemptible unless it cooperates via timeslice accounting. See
[02_nif_taxonomy_rustler.md](02_nif_taxonomy_rustler.md).

## Rustler

A Rust library that generates safe wrappers around the Erlang NIF API.
Handles term encoding/decoding, catches Rust panics, and exposes a
`#[nif]` attribute macro. See
[02_nif_taxonomy_rustler.md](02_nif_taxonomy_rustler.md).

## Dirty NIF

A NIF scheduled on a dirty scheduler instead of a normal one. Used for
operations that can't complete within a normal reduction budget.
- `schedule = "DirtyCpu"` — CPU-bound work
- `schedule = "DirtyIo"` — I/O-bound work (sleep, socket, file)

## Port

An OS process connected to BEAM via a port. Communication is via stdin/stdout
message framing. If the port process crashes, BEAM survives (the port owner
gets a terminate signal). This lab's port binary is `lab_port`. See E17.

## Resource

An opaque BEAM term wrapping a native C/Rust pointer. Created with
`enif_alloc_resource` (Rustler: `ResourceArc::new`). Garbage-collected when
all Elixir references die and a finalizer runs. See E10.

## ResourceArc

Rustler's smart pointer for resources. When the last Elixir reference drops,
Rustler runs the resource's `Drop` implementation.

## Oban

A durable job queue for Elixir backed by Postgres. Used in E20 to test how
long native operations interact with a real job system.

## Ecto

A database wrapper and query generator for Elixir. Used with Postgrex for
Postgres access in this lab.

## Postgrex

A PostgreSQL driver for Elixir. Used by Ecto and Oban.

## Telemetry

A standard Elixir library for emitting and observing metrics events. This lab
uses `telemetry`, `telemetry_metrics`, and broadcasts to LiveView via PubSub.

## PubSub

Phoenix's publish/subscribe mechanism. `lab_core` emits telemetry; LiveView
processes subscribe and update the UI in real time.

## LiveView

Phoenix LiveView — server-rendered HTML that updates in real time over
WebSockets without client-side JavaScript frameworks. This lab's control room
is a LiveView application.

## Run queue

The queue of processes waiting to run on a scheduler. Length indicates
contention. `:erlang.statistics(:run_queue)` or `:erlang.process_info`.

## scheduler_wall_time

`:erlang.statistics(:scheduler_wall_time)` returns per-scheduler busy/idle
time. Used to compute utilization percentages. See
[03_measurement_protocol.md](03_measurement_protocol.md).

## RSS

**Resident Set Size** — the portion of a process's memory held in RAM. Read
from `/proc/<pid>/status` (field `VmRSS`). Used to track native memory growth
that BEAM's internal accounting may not see. See E09.

## OOM

**Out Of Memory** — when the OS kills a process that exceeds memory limits.
In Docker, the container is killed. See E09, E18.

## Segfault

**Segmentation fault** — a process accesses memory it shouldn't. The OS
delivers SIGSEGV; the process dies. Rustler cannot catch this. See E14.

## Panic

Rust's runtime-abort mechanism for unrecoverable errors. Rustler catches
panics in NIFs and converts them to Erlang terms. See E08.

## Isolated child BEAM

A separate BEAM OS process spawned by the UI's BEAM to run crash experiments
(E03, E08, E11, E14, E16). The child may die; the UI's BEAM survives and
records the death. See [ADR 0002](adr/0002_isolated_child_beam_for_crashes.md).

## in_process

An experiment execution mode where the workload runs in the UI's own BEAM.
Used by non-crash experiments. The UI may freeze during scheduler-blocking
experiments — that freezing is evidence. See
[07_ui_architecture.md](07_ui_architecture.md).

## Threshold

A numeric assertion in an experiment's test. E.g. `latency_p99_max_ms: 50`
means the test fails if p99 latency exceeds 50ms. See
[06_reproducibility_protocol.md](06_reproducibility_protocol.md).

## Golden baseline

A recorded set of metrics from a reference run, stored in
`experiments/E##/baselines/`. Used to detect regressions across BEAM/Rustler
versions. See [06_reproducibility_protocol.md](06_reproducibility_protocol.md).
