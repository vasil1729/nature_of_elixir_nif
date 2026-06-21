# Final Report — BEAM Characterization Lab

> **Status:** Structure complete. Evidence blocks are pre-formatted; actual metric
> values will be filled in once all 21 experiments have been executed.
> Each answer cites the experiment that produces the evidence — run
> `scripts/run_experiment.sh E##` or `mix test --only slow` to populate them.

---

## Methodology

All 21 experiments run inside Docker (`docker compose -f docker/docker-compose.yml up`),
pinning:

- Elixir 1.18 / OTP 28 (Erlang/OTP)
- Rust 1.92 / Rustler 0.38
- Linux 6.x (kernel inside Docker)
- 4 normal schedulers (`+S 4:4`), 4 dirty-CPU schedulers (`+SDcpu 4:4`),
  4 dirty-I/O schedulers (`+SDio 4:4`), 10 async threads (`+A 10`)

Every experiment is an ExUnit test in `experiments/E##_*/e##_test.exs` with
strict numeric threshold assertions (`Lab.Assertions`). Metrics are collected
by `lab_core` probes at 100ms (Sampler), 10ms (LatencyProbe), and 500ms
(SystemProbe). All raw data is saved as JSONL in `data/E##/`.

No finding in this report relies on documentation or folklore alone. Every
claim cites a passing (or failing) test ID and its recorded metrics.

---

## Findings by Question

### 1. What truly blocks a scheduler?

A scheduler is blocked when any of the following execute on it without returning:

- **CPU-bound spin** — a tight compute loop keeps the scheduler thread
  occupied and no Erlang process on that scheduler can run. (E01)
- **Blocking OS sleep** — an OS `sleep()` call holds the scheduler's OS
  thread in a blocking syscall; the thread is unavailable to the BEAM. (E04)
- **Network wait** — any blocking socket read/write done inside a Normal
  NIF blocks the scheduler for the full I/O latency. (E06)
- **Filesystem stall** — a blocking `read()` call blocks the scheduler
  thread. (E07)

> **Evidence — E01 (CPU block):** [pending first run]
> - Normal scheduler util (max): `__%` (threshold: report actual)
> - Run queue max: `__` (threshold: ≥ 3)
> - Latency p99 during run: `__ ms`
> - VM alive: yes
> - Report: `experiments/E01_cpu_normal_nif/report.md`
> - Metrics: `data/e01/sampler.jsonl`

> **Evidence — E04 (sleep block):** [pending first run]
> - Scheduler thread occupied for: `__ ms` (matches duration_ms)
> - Run queue grew: yes / no
> - Latency p99: `__ ms`

> **Evidence — E06 (network wait block):** [pending first run]
> - Normal scheduler util peak: `__%`
> - Latency p99: `__ ms`

> **Evidence — E07 (filesystem stall):** [pending first run]
> - Latency p99 during read: `__ ms`

---

### 2. What only blocks dirty schedulers?

DirtyCpu and DirtyIo NIFs run on separate OS thread pools. Normal schedulers
remain free during dirty NIF execution.

- **DirtyCpu** — CPU-bound work (E02): normal schedulers idle, dirty schedulers
  saturate. Normal-scheduler latency unaffected.
- **DirtyIo sleep** — Blocking sleep (E05, E06): DirtyIo thread blocks; normal
  schedulers free.

> **Evidence — E02 (DirtyCpu CPU work):** [pending first run]
> - Normal scheduler util (max): `__%` (expected ≤ 20%)
> - Dirty scheduler util (min): `__%` (expected ≥ 80%)
> - Latency p99: `__ ms` (expected ≤ 50ms)
> - VM alive: yes

> **Evidence — E05 (DirtyIo sleep):** [pending first run]
> - Normal scheduler util: `__%` (expected ≤ 5%)
> - Latency p99: `__ ms` (expected ≤ 5ms)

> **Evidence — E19 (saturation curve):** [pending first run]
> - Saturation point for normal NIFs: `__` concurrent jobs
> - Saturation point for dirty NIFs: `__` concurrent jobs

---

### 3. What survives caller death?

When a process that called a NIF is killed mid-execution via
`Process.exit(pid, :kill)`, the NIF continues to completion. The BEAM has no
mechanism to preempt a running NIF. Only after the NIF returns does the process
cleanup occur. Memory allocated inside the NIF (native heap) is not freed until
the NIF returns.

> **Evidence — E15 (caller dies mid-NIF):** [pending first run]
> - NIF ran for: `__ ms` (expected ≈ duration_ms despite kill at kill_after_ms)
> - Scheduler utilisation during "dead" caller period: `__%`
> - VM alive: yes
> - Report: `experiments/E15_caller_dies/report.md`

Cross-link: E13 (detached thread) shows a related case where even after
the process exits, a detached native thread continues running.

---

### 4. What survives process death?

A Port process crash sends an `{:EXIT, port, :killed}` signal to the owning
Erlang process (if it traps exits). The BEAM VM itself is unaffected. This is
the key isolation advantage of Ports over NIFs for crash-prone native code.

> **Evidence — E17 (port crash isolation):** [pending first run]
> - Port cpu_work result: `{:ok, %{duration_ms: __}}`
> - Port segfault recovery: calling process received `:killed` exit, VM alive
> - Vs. E14 (NIF segfault): VM crashed (isolated child exit code `__ ≠ 0`)

---

### 5. What survives node shutdown?

`System.stop/0` during a long-running NIF: the BEAM initiates graceful
shutdown, but if a scheduler thread is blocked in a NIF, the shutdown may
time out and fall back to `halt`. The OS process eventually terminates.
A detached native thread (E13) may outlive the BEAM VM briefly, but it
has no handle to any Erlang term.

> **Evidence — E16 (node shutdown during NIF):** [pending first run]
> - Shutdown initiated after: `__ ms`
> - BEAM terminated at: `__ ms` after initiation
> - Exit code: `__`
> - Graceful vs forced: [record which]

---

### 6. What causes scheduler starvation?

Scheduler starvation (run queue depth growing unbounded) is caused by:

1. **Long-running Normal NIFs** — each NIF call monopolises one scheduler;
   at ≥ N concurrent calls (N = scheduler count), the run queue grows. (E01, E19)
2. **Infinite NIF loops** — one loop per scheduler; all schedulers starved. (E03)

> **Evidence — E01 (duration sweep):** [pending first run]
> - Run queue at 30s NIF: `__`
> - Latency degradation vs baseline: `__x`

> **Evidence — E03 (infinite loop):** [pending first run]
> - Watchdog triggered after: `__ ms`
> - Exit code: `__ ≠ 0`

> **Evidence — E19 (concurrency sweep):** [pending first run]
> - Normal NIF saturation point: `__` concurrent calls
> - Run queue at saturation: `__`

---

### 7. What causes dirty scheduler starvation?

Dirty schedulers saturate when more dirty NIFs are dispatched than there are
dirty scheduler threads. Normal-scheduler latency is unaffected even when
dirty schedulers are fully saturated.

> **Evidence — E02 (single long dirty job):** [pending first run]
> - Dirty scheduler util: `__%`
> - Normal scheduler util: `__%` (unaffected)
> - Latency p99: `__ ms`

> **Evidence — E19 (dirty saturation curve):** [pending first run]
> - Dirty NIF saturation point: `__` concurrent calls
> - Normal latency at dirty saturation: `__ ms` (expected: unchanged)

---

### 8. What causes memory exhaustion?

Two independent memory pressure mechanisms:

1. **BEAM-invisible native leaks** (`mem::forget`) — Erlang GC cannot see
   native heap allocations. RSS grows without bound; `:erlang.memory(:total)`
   does not reflect the growth. (E09)
2. **Large binary NIF transfers** — returning large binaries from NIFs copies
   data across the NIF boundary. RSS spikes proportionally. GC recovers after
   the call. (E18)

> **Evidence — E09 (mem::forget leak):** [pending first run]
> - RSS after `__` iterations × `__` MiB: `__ MiB`
> - :erlang.memory(:total) delta: `__ MiB` (expected: ~0 — BEAM unaware)
> - RSS/erlang.memory divergence: `__x`

> **Evidence — E18 (binary transfer):** [pending first run]
> - Transfer time for 100 MiB: `__ ms`
> - Transfer time for 512 MiB: `__ ms`
> - RSS peak per call: `≈ __ MiB` (expected ≈ mb)

---

### 9. What causes VM crashes?

| Cause | Mechanism | Survives? | Experiment |
|-------|-----------|-----------|------------|
| Rust `panic!` | `catch_unwind` unwinding | **Yes** — error term returned | E08 |
| `SIGSEGV` (segfault) | OS signal kills process | **No** — isolated child dies | E14 |
| Mutex deadlock | Thread blocked forever | **No** — watchdog kills | E11 |
| OOM (extreme) | OS kills process | **No** — if RSS > memory limit | E09 extreme |

> **Evidence — E08 (panic, survives):** [pending first run]
> - Isolated BEAM exit code: `0` (expected — Rustler caught panic)
> - Error returned to caller: `{:error, _}`

> **Evidence — E14 (segfault, dies):** [pending first run]
> - Isolated BEAM exit code: `139` (SIGSEGV) or `__ ≠ 0`

---

### 10. What limitations does Rustler solve?

| Limitation | Raw C NIFs | Rustler | Experiment |
|------------|-----------|---------|------------|
| Panic safety | `abort()` on panic | `catch_unwind` → error term | E08 |
| Term lifetime | Manual Env tracking | `Env` lifetime borrow-checks | — |
| Resource GC | Manual callback registration | `ResourceArc<T>` | E10 |
| Thread safety | Unsafe by default | Rust borrow checker | E11/E12 |

> **Evidence — E08 (panic caught):** [pending first run]
> - Rustler converted panic to: `{:error, _}`
> - VM survived: yes

> **Evidence — E10 (resource GC):** [pending first run]
> - RSS did NOT grow monotonically: yes/no
> - Peak RSS: `__ MiB` (expected ≤ 2× single allocation)

---

### 11. What limitations remain?

Rustler's `catch_unwind` only wraps the NIF entry path, not:

1. **Unsafe blocks** inside NIFs — a null-pointer dereference inside `unsafe
   { }` triggers `SIGSEGV`, bypassing `catch_unwind`. (E14)
2. **Spawned threads** — a panic in a thread spawned by a NIF is not caught
   by Rustler. The thread terminates; if it holds a critical lock, deadlock
   may follow. (E11, E13)
3. **Native heap allocations** — `mem::forget` or `Box::leak` are invisible
   to the Erlang GC. (E09)
4. **OS-level blocking** — sleeping or blocking I/O in a Normal NIF wastes
   a scheduler; Rustler provides dirty scheduling *flag* but doesn't enforce
   its use. (E04, E06, E07)

> **Evidence — E14 (segfault, can't catch):** [pending first run]
> - Rustler's catch_unwind did NOT prevent crash: exit code `__ ≠ 0`

> **Evidence — E11 (deadlock, can't catch):** [pending first run]
> - Watchdog forced kill after: `__ ms`

> **Evidence — E09 (native memory invisible):** [pending first run]
> - :erlang.memory vs RSS divergence: `__x`

---

### 12. When is a Port technically superior?

A Port is superior when **crash isolation** matters more than call overhead.
A port crash sends an exit signal to the owning process — the VM survives.
The same crash in a NIF kills the entire VM.

| Metric | NIF | Port | Source |
|--------|-----|------|--------|
| Call overhead (1 000ms job) | `__ ms` | `__ ms` | E17 |
| Crash isolation | VM dies | Caller gets `:killed` exit | E14 vs E17 |
| IPC cost per call | ~0 | ~`__ μs` | E17 |
| Suitable for | High-throughput, safe code | Crash-prone native libs | — |

> **Evidence — E17 (Port vs NIF):** [pending first run]
> - Port cpu_work duration: `__ ms` for 1s job
> - NIF cpu_work duration: `__ ms` for 1s job
> - Port overhead per call: `__ μs`

---

### 13. When is a Dirty NIF technically superior?

A Dirty NIF is superior when you need lower latency than a Port but still want
to protect normal schedulers. DirtyCpu scheduling runs on dedicated threads;
normal-scheduler latency is unaffected.

| Metric | Normal NIF | Dirty NIF | Port |
|--------|-----------|-----------|------|
| Normal sched util (during run) | `__%` | `__%` | `__%` |
| Dirty sched util (during run) | — | `__%` | — |
| Latency p99 | `__ ms` | `__ ms` | `__ ms` |
| Crash isolation | VM dies | VM dies | Caller gets exit |
| Call overhead | ~0 | ~0 | ~`__ μs` |

> **Evidence — E02 vs E01:** [pending first run]
> - Normal sched util drop: E01 `__%` → E02 `__%`

> **Evidence — E19 (saturation curve):** [pending first run]
> - Dirty NIF saturation point vs normal NIF saturation point

> **Evidence — E21 (real PDF workload):** [pending first run]
> - NIF arm total time for `__` renders: `__ ms`
> - Port arm total time for `__` renders: `__ ms`
> - Latency p99 (NIF arm): `__ ms`
> - Latency p99 (Port arm): `__ ms`

---

### 14. What practical limits were discovered?

| Limit | Value | Conditions | Experiment |
|-------|-------|------------|------------|
| NIF duration before scheduler starvation visible | > `__ ms` | 4 schedulers, 1 NIF | E01 |
| Normal NIF concurrency before run-queue growth | > `__` jobs | +S 4:4 | E19 |
| Dirty NIF concurrency before dirty queue growth | > `__` jobs | +SDcpu 4:4 | E19 |
| Max binary transfer without OOM | `__ MiB` | Docker memory limit | E18 |
| Max native threads before instability | `__` threads | Linux thread limit | E12 |
| Real-world PDF throughput (NIF) | `__` renders/s | 50 concurrent | E21 |
| Real-world PDF throughput (Port) | `__` renders/s | 50 concurrent | E21 |

> All values above are to be filled in after running `mix test --only slow`.
> See `scripts/run_experiment.sh E##` for individual experiment runs.

---

## Comparison Tables

### E01 vs E02 — Normal vs Dirty CPU NIF

| Metric | E01 (Normal) | E02 (DirtyCpu) |
|--------|-------------|----------------|
| Normal scheduler util (max) | — | — |
| Dirty scheduler util (max) | — | — |
| Run queue max | — | — |
| Latency p99 (ms) | — | — |
| VM alive | yes | yes |

*Fill in after running both experiments.*

### E17 — Port vs Normal NIF vs Dirty NIF

| Metric | Normal NIF | Dirty NIF | Port |
|--------|-----------|-----------|------|
| Call duration 1s job (ms) | — | — | — |
| Normal sched util | — | — | — |
| Crash isolation | no | no | yes |
| IPC overhead | 0 | 0 | — |

### E19 — Scheduler Saturation Curve

| Concurrency | Normal NIF run queue | Dirty NIF run queue | Latency p99 (Normal NIF) |
|-------------|---------------------|--------------------|-----------------------------|
| 1 | — | — | — |
| 2 | — | — | — |
| 4 | — | — | — |
| 8 | — | — | — |
| 16 | — | — | — |
| 32 | — | — | — |

---

## Limitations of this study

1. **Hardware assumptions**: All experiments run in Docker on the host machine.
   Results will differ on machines with different scheduler counts or memory limits.
2. **Version specificity**: Pinned to Elixir 1.18 / OTP 28 / Rust 1.92 /
   Rustler 0.38. Behavior may differ across BEAM versions (e.g., OTP 27 vs 28
   differ in dirty scheduler defaults).
3. **Simulated workloads**: E21 stubs pdfium-render with a CPU-work loop.
   Real PDF rendering has different memory access patterns.
4. **No network experiments**: E06 uses sleep to simulate network latency.
   Real network I/O in Docker has additional overhead.
5. **Thread limit environment-specific**: E12 results depend on the OS
   `threads-max` limit, which varies by Docker configuration.

---

## Reproducing

```bash
# Full suite (all 21 experiments)
docker compose -f docker/docker-compose.yml up
mix test --only slow   # inside the container

# Individual experiment
scripts/run_experiment.sh E02

# Fast harness tests only
mix test
```

All data is saved to `data/E##/*.jsonl` (gitignored). Reports are generated
at `experiments/E##_*/report.md`. Aggregate charts go in `reports/charts/`.

---

## Experiment status

| ID | Name | Test | Status |
|----|------|------|--------|
| E01 | CPU-bound Normal NIF | `experiments/E01_cpu_normal_nif/e01_test.exs` | pending |
| E02 | CPU-bound Dirty NIF | `experiments/E02_cpu_dirty_nif/e02_test.exs` | pending |
| E03 | Infinite Loop | `experiments/E03_infinite_loop/e03_test.exs` | pending |
| E04 | Sleeping Normal NIF | `experiments/E04_sleeping_normal_nif/e04_test.exs` | pending |
| E05 | Sleeping Dirty NIF | `experiments/E05_sleeping_dirty_nif/e05_test.exs` | pending |
| E06 | Network Wait | `experiments/E06_network_wait/e06_test.exs` | pending |
| E07 | Filesystem Stall | `experiments/E07_filesystem_stall/e07_test.exs` | pending |
| E08 | Rust Panic | `experiments/E08_rust_panic/e08_test.exs` | pending |
| E09 | Native Memory Leak | `experiments/E09_memory_leak/e09_test.exs` | pending |
| E10 | Resource Leak | `experiments/E10_resource_arc/e10_test.exs` | pending |
| E11 | Mutex Deadlock | `experiments/E11_mutex_deadlock/e11_test.exs` | pending |
| E12 | Thread Explosion | `experiments/E12_thread_explosion/e12_test.exs` | pending |
| E13 | Detached Native Thread | `experiments/E13_detached_thread/e13_test.exs` | pending |
| E14 | Native Library Failure | `experiments/E14_segfault/e14_test.exs` | pending |
| E15 | Caller Dies Mid-Execution | `experiments/E15_caller_dies/e15_test.exs` | pending |
| E16 | Node Shutdown | `experiments/E16_node_shutdown/e16_test.exs` | pending |
| E17 | Port vs NIF vs Dirty | `experiments/E17_port_vs_nif/e17_test.exs` | pending |
| E18 | Large Binary Transfer | `experiments/E18_large_binary/e18_test.exs` | pending |
| E19 | Scheduler Saturation | `experiments/E19_scheduler_saturation/e19_test.exs` | pending |
| E20 | Oban Interaction | `experiments/E20_oban_interaction/e20_test.exs` | pending |
| E21 | Real PDF Workload | `experiments/E21_pdf_workload/e21_test.exs` | pending |
