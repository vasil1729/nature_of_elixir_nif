# 02 — NIF Taxonomy & Rustler Internals

> This document explains the NIF mechanism and what Rustler does and doesn't
> protect against. Every claim about behavior is a **starting reference** that
> an experiment verifies. Each section links to the experiment(s) that test it.

## The four NIF scheduling classes

| Class | Rustler annotation | Runs on | Preemptible? |
|-------|-------------------|---------|--------------|
| Normal | `#[nif]` (default) | Normal scheduler | No (unless cooperative) |
| DirtyCpu | `#[nif(schedule = "DirtyCpu")]` | Dirty CPU scheduler | No |
| DirtyIo | `#[nif(schedule = "DirtyIo")]` | Dirty IO scheduler | No |
| None | `ERL_NIF_DIRTY_JOB_SCHEDULER_TYPE_NONE` | Caller's scheduler (rare) | No |

**"Preemptible?" is "No" for all of them.** Dirty schedulers don't magically
make a NIF preemptible — they isolate it from normal schedulers. The
fundamental rule still holds: a NIF that doesn't return holds its scheduler
hostage. See [01_beam_scheduler_model.md](01_beam_scheduler_model.md).

This lab's `lab_native` crate exposes most NIFs in both Normal and Dirty
variants so experiments can compare directly (E01 vs E02, E04 vs E05).

## What Rustler is

Rustler is a Rust library that generates the C glue for Erlang NIFs. It does
three big things:

1. **Term encoding/decoding** — `NifStruct`, `NifTuple`, `NifEnum` derive
   macros; automatic `Encoder`/`Decoder` for primitives. You write Rust
   types; Rustler handles the BEAM term conversion.
2. **The `#[nif]` macro** — expands a Rust function into the C entry point
   BEAM expects, wiring up `enif_make_*` calls and the resource environment.
3. **Panic safety** — catches `panic!` inside a NIF and converts it to an
   Erlang term (`{:error, :panic}` or similar). See E08.

## What Rustler catches

### Panic (E08)

A `panic!` inside a `#[nif]` function is caught by Rustler's
`std::panic::catch_unwind` wrapper. The NIF returns an error term; the
calling Elixir process gets an exception; **the BEAM survives.**

This is the single most important safety property Rustler provides over raw C
NIFs, where a `longjmp`-based "panic" is easy to get wrong. **E08 verifies
this.**

What E08 also tests: *what exactly* survives. The process that called the
NIF? Its supervisor? The node? The hypothesis: the process dies (exception
propagates), everyone else lives. Rustler doesn't catch panics in spawned
native threads, however — only in the NIF entry itself.

## What Rustler does NOT catch

### Segfault (E14)

A null-pointer dereference or out-of-bounds write kills the OS process. The
signal handler that Rustler installs does **not** recover from SIGSEGV. The
entire BEAM dies — every process, every scheduler, the node.

**E14 verifies this** by deliberately dereferencing a null pointer (via
`std::ptr::null_mut()` and a volatile read to defeat the optimizer). The
expected outcome: BEAM exits with SIGSEGV; in the UI's isolated child BEAM
mode, the child dies and the UI records the exit code.

### `abort` / `std::process::abort`

Same as segfault: process dies, no catch. Distinct from panic, which
`catch_unwind` handles unless someone sets
`panic = "abort"` in `Cargo.toml`. **This lab keeps `panic = "unwind"`**
so E08's panic path is meaningful. E14 may also test `abort` as a sub-case.

### Undefined behavior in `unsafe` blocks

Rust's `unsafe` is a permission slip, not a guard. A use-after-free, data
race, or aliased mutable reference in `unsafe` code can corrupt memory in
ways that crash immediately, crash later, or silently produce wrong results.
Rustler can't see inside `unsafe` blocks. **E14 explores this boundary.**

### Panics in spawned native threads (E13)

`std::thread::spawn` creates a real OS thread. If it panics, the panic
unwinds that thread — not the NIF. Rustler's `catch_unwind` is on the NIF
entry path, not inside spawned threads. A panicked thread prints to stderr
and dies; the BEAM may or may not notice.

**E13 (detached thread) and E12 (thread explosion) touch this.** A panicked
detached thread is invisible to BEAM and leaks its stack.

## The C boundary — what crosses it

Every NIF call crosses the BEAM↔C boundary. The cost has three parts:

1. **Term encoding** — Rustler decodes the Elixir arguments into Rust types.
   For small terms (integers, atoms) this is cheap; for large binaries or
   deep lists it's significant. **E18 measures this** with 10MB→1GB binaries.
2. **The call itself** — zero overhead beyond a C function call.
3. **Term encoding out** — Rustler encodes the return value. Returning a
   1GB binary means copying/aliasing 1GB of memory into the BEAM binary
   heap. **E18 measures this too.**

### Binaries: the `OwnedBinary` / `Binary` distinction

Rustler can return a binary two ways:
- `Binary` — a reference to BEAM-managed memory; no copy, but the data must
  already live in a BEAM binary.
- `OwnedBinary` — Rust-owned memory that gets handed to BEAM. This may
  involve a copy. For huge buffers it's the dominant cost. E18 uses this.

## Resource types and finalizers (E10)

A **resource** is an opaque BEAM term wrapping a native pointer. Lifetime:

1. Elixir calls a NIF that returns `ResourceArc::new(data)`.
2. BEAM holds the resource term; the `ResourceArc` is reference-counted by
   BEAM's GC.
3. When the last Elixir reference drops, BEAM's GC eventually runs the
   resource's `Drop` implementation (the "finalizer").
4. Rust memory is freed at that point — **not** when the Elixir reference
   drops, but when GC collects it.

**E10 tests the lag** between Elixir reference dropping and Rust memory
actually freeing. The hypothesis: there's a measurable gap, and it depends on
GC pressure. BEAM's memory reporting (`:erlang.memory(:total)`) may not
account for resource-held Rust memory until `Drop` runs.

## The `Env` lifetime trick

Rustler's `Env<'a>` is tied to the NIF call's lifetime. Terms created with
that `env` are only valid during the call. This prevents returning a borrowed
term after the NIF returns — a common C-NIF footgun that Rustler eliminates
at compile time.

`ResourceArc` and `Binary` escape this: they're refcounted/ref-holding and
survive across calls. `Env`-bound terms don't.

## What this taxonomy predicts (hypotheses the experiments test)

| Prediction | Experiment | Outcome |
|------------|------------|---------|
| A Rust panic inside a NIF returns an error term; BEAM lives | E08 | *to be measured* |
| A segfault inside a NIF kills the entire BEAM | E14 | *to be measured* |
| Resource memory frees at GC time, not at reference-drop | E10 | *to be measured* |
| Large binary return cost scales with binary size | E18 | *to be measured* |
| A panicked spawned thread doesn't crash the BEAM | E13 | *to be measured* |

## Further reading (starting references only — not authorities)

- [Rustler guide](https://rustler.cargo.burgers.io/) — term encoding, resources
- [erl_nif: resource types](https://www.erlang.org/doc/man/erl_nif.html#resource_types)
- [Rustler panic handling](https://github.com/rusterlium/rustler#panic-handling)

These describe intended behavior. **E08, E10, E13, E14, E18 verify it.**
