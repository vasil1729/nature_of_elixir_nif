# 01 — BEAM Scheduler Model

> This document explains the mechanisms the experiments probe. Every claim
> about behavior is a **starting reference** that an experiment verifies — not
> an authority. Each section links to the experiment(s) that test it.

## Why this matters

The single most important thing to understand about BEAM is that **schedulers
are OS threads that run Erlang/Elixir processes via cooperative-ish
preemption, and NIFs break that model.** Most folklore about "NIFs are
dangerous" reduces to: a NIF that doesn't return breaks the scheduler's
ability to preempt. The experiments in this lab turn that sentence into
numbers.

## Schedulers at a glance

| Kind | What runs there | Flag | Count on this host |
|------|-----------------|------|--------------------|
| Normal scheduler | BEAM processes (Elixir/Erlang code) | `+S` | 4 (`+S 4:4`) |
| Dirty CPU scheduler | Long CPU-bound NIFs | `+SDcpu` | 4 (`+SDcpu 4:4`) |
| Dirty IO scheduler | Long I/O-bound NIFs | `+SDio` | 4 (default: same as `+SDcpu`) |
| Async thread pool | Driver async jobs (file I/O, etc.) | `+A` | 1 (default; we may raise) |

This lab pins `+S 4:4 +SDcpu 4:4 +SDio 4:4` in every experiment so results are
comparable. The host shows `[smp:4:4] [ds:4:4:10]` — 4 normal, 4 dirty, 10
async threads.

## Reduction-budget preemption (the core mechanism)

BEAM does **not** preempt at arbitrary points. Each process has a
**reduction budget** (≈ 2000 by default). Every function call, message send,
and GC tick decrements it. When the budget hits zero, the scheduler switches
to the next runnable process.

This is why BEAM feels concurrent with tens of thousands of processes: each
runs for a tiny slice, then yields. No single process can monopolize a
scheduler — **as long as it's running BEAM code.**

### Where this breaks: NIFs

A NIF is a single C function call from BEAM's perspective. The reduction
budget is checked **before and after** the call — not during. If a NIF runs
for 30 seconds, the scheduler thread running it is stuck in C for 30 seconds:
no process switching, no run queue draining, no responsiveness.

This is the central fact E01 measures. See:
- **E01** — CPU-bound normal NIF for 100ms→60s. Watch latency collapse.
- **E03** — Infinite loop normal NIF. Watch the scheduler never come back.

### The cooperative escape hatch: `enif_consume_timeslice`

A long NIF *can* cooperate by calling `enif_consume_timeslice(env, percent)`
to report how much budget it has used. If it reports enough, the scheduler
may yield and resume the NIF later. Rustler exposes this via
`env.saved_schedule_time()` / `env.reduce()` on newer versions.

Most NIFs in this lab **deliberately do not cooperate** — the point is to
observe what happens when they don't. E02 contrasts this with DirtyCpu.

## Dirty schedulers

Dirty schedulers exist to keep long native operations off normal schedulers.
A NIF annotated `schedule = "DirtyCpu"` (Rustler) or
`ERL_NIF_DIRTY_JOB_SCHEDULER_CPU_BOUND` (C) runs on a dirty CPU scheduler
instead of a normal one.

**Key properties (to be verified):**
- Normal schedulers should remain free while a DirtyCpu NIF runs → **E02**
- Dirty schedulers have their own run queues → **E19**
- A dirty scheduler runs one dirty job at a time; saturating all of them
  queues the rest → **E19**

### DirtyCpu vs DirtyIo

| Flavor | Intended for | Examples in this lab |
|--------|--------------|----------------------|
| DirtyCpu | CPU-bound work (spinning, hashing, parsing) | E02, E19, E20, E21 |
| DirtyIo | I/O-bound work (sleep, socket, file) | E05, E06, E07 |

**Why the split matters:** CPU-bound jobs on a dirty IO scheduler would block
I/O jobs; I/O jobs on a dirty CPU scheduler would underutilize the CPU
schedulers. BEAM keeps separate pools. E05/E06/E07 verify that DirtyIo
doesn't DirtyCpu-block and vice versa.

## The async thread pool (`+A`)

Separate from dirty schedulers. Used by **linked-in drivers** for async work
(e.g. file I/O via the `file` driver). A NIF can spawn a thread via
`enif_thread_create` that runs on this pool's machinery. Not directly tested
by most experiments, but E13 (detached thread) and E12 (thread explosion)
touch the underlying OS-thread behavior that the async pool also relies on.

## Scheduler wall time — how we measure utilization

`:erlang.statistics(:scheduler_wall_time)` returns, per scheduler, the total
busy and idle time accumulated since the call. To compute utilization:

```elixir
{:scheduler_wall_time, entries} = :erlang.statistics(:scheduler_wall_time)
# entries: [{1, busy, idle}, {2, busy, idle}, ...]
util = busy / (busy + idle)
```

To get a **windowed** utilization, sample twice and diff. `lab_core.Sampler`
does this every 100ms → JSONL + PubSub broadcast. See
[03_measurement_protocol.md](03_measurement_protocol.md).

Dirty schedulers appear in the same list, keyed by scheduler id ≥ normal
count. We split them in the UI's `SchedulerBar` component.

## Run queues

Each scheduler has a run queue (processes ready to run). Total queue length
is `:erlang.statistics(:run_queue)`; per-scheduler is available via
`:erlang.system_info(:scheduler_bindings)` and friends.

A growing run queue means processes are ready but no scheduler is picking
them up — the signature of starvation. E01 and E19 watch this number climb.

## What this model predicts (hypotheses the experiments test)

| Prediction | Experiment | Outcome |
|------------|------------|---------|
| A 30s normal NIF blocks one scheduler entirely | E01 | *to be measured* |
| Normal schedulers stay free during a 30s DirtyCpu NIF | E02 | *to be measured* |
| An infinite-loop normal NIF permanently blocks a scheduler | E03 | *to be measured* |
| A sleeping normal NIF blocks a scheduler despite zero CPU | E04 | *to be measured* |
| DirtyIo jobs don't block DirtyCpu schedulers | E05/E06/E07 | *to be measured* |
| Dirty schedulers queue when jobs > schedulers | E19 | *to be measured* |

*"to be measured"* entries get filled in by the experiment's `report.md` once
it runs. The doc is a starting reference; the experiment is the authority.

## Further reading (starting references only — not authorities)

- [Erlang Run-Time System Application: erl](https://www.erlang.org/doc/man/erl.html) — `+S`, `+SDcpu`, `+SDio`, `+A` flags
- [erlang:statistics/1](https://www.erlang.org/doc/man/erlang.html#statistics-1) — `scheduler_wall_time`
- [NIF docs: dirty schedulers](https://www.erlang.org/doc/man/erl_nif.html#dirty-schedulers)

These describe intended behavior. **E01–E07, E19 verify it.**
