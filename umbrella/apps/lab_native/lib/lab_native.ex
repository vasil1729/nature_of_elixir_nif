defmodule Lab.Native do
  @moduledoc """
  Rustler NIF interface for the BEAM Characterization Lab.

  This module loads the `lab_native` Rust crate and exposes its NIFs.
  Each NIF has Normal and Dirty variants (where applicable) — see
  docs/02_nif_taxonomy_rustler.md and docs/09_architecture.md.

  ## NIFs by Theme

  ### Theme A — Scheduler Blocking
  | NIF | Schedule | Experiments |
  |-----|----------|-------------|
  | `hello/0` | Normal | smoke test |
  | `cpu_work_ms/1` | Normal | E01, E19, E20 |
  | `cpu_work_ms_dirty/1` | DirtyCpu | E02, E19 |
  | `infinite_loop/0` | Normal | E03 (normal arm) |
  | `infinite_loop_dirty/0` | DirtyCpu | E03 (dirty arm) |
  | `sleep_for_ms/1` | Normal | E04, E06 |
  | `sleep_for_ms_dirty_io/1` | DirtyIo | E05, E06 |
  | `fs_read_bytes/1` | Normal | E07 |
  | `fs_read_bytes_dirty_io/1` | DirtyIo | E07 |

  ### Theme B — Failure Modes
  | NIF | Schedule | Experiments |
  |-----|----------|-------------|
  | `panic_now/0` | Normal | E08 |
  | `leak_memory_mb/1` | Normal | E09 |
  | `make_resource/1` | Normal | E10 |
  | `deadlock/0` | DirtyCpu | E11 |
  | `spawn_threads/1` | Normal | E12 |
  | `detach_thread/1` | Normal | E13 |
  | `segfault/0` | Normal | E14 |

  ### Theme D — Scale
  | NIF | Schedule | Experiments |
  |-----|----------|-------------|
  | `large_binary_mb/1` | Normal | E18 |

  ### Theme E — Real-World
  | NIF | Schedule | Experiments |
  |-----|----------|-------------|
  | `pdf_work/1` | Normal | E21 |
  | `pdf_work_dirty/1` | DirtyCpu | E21 |

  NIFs are added per-experiment (see docs/10_development_guide.md).
  """

  use Rustler,
    otp_app: :lab_native,
    crate: :lab_native

  # Fallback definitions — replaced by NIFs when the crate loads.
  # If the .so isn't found, these raise with a helpful message.

  @doc "Smoke-test NIF. Returns `:ok` if the crate loaded."
  def hello, do: :erlang.nif_error(:nif_not_loaded)

  # ── Theme A: Scheduler Blocking ──────────────────────────────────────────────

  @doc """
  CPU-bound work for `ms` milliseconds. Normal-scheduled.

  Blocks the calling scheduler for the full duration. Used by E01 to
  demonstrate scheduler starvation.
  """
  def cpu_work_ms(_ms), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  CPU-bound work for `ms` milliseconds. DirtyCpu-scheduled.

  Runs on a dirty CPU scheduler, leaving normal schedulers free.
  Used by E02 to demonstrate dirty scheduler isolation.
  """
  def cpu_work_ms_dirty(_ms), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Infinite CPU loop. Normal-scheduled — will starve the BEAM entirely (E03).
  Must only be called inside an isolated child BEAM (ADR 0002).
  """
  def infinite_loop, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Infinite CPU loop. DirtyCpu-scheduled — normal schedulers survive (E03).
  """
  def infinite_loop_dirty, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  OS-level sleep for `ms` milliseconds. Normal-scheduled.
  Wastes a normal scheduler thread. E04, E06.
  """
  def sleep_for_ms(_ms), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  OS-level sleep for `ms` milliseconds. DirtyIo-scheduled.
  Correct way to block on I/O. E05, E06.
  """
  def sleep_for_ms_dirty_io(_ms), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Reads `bytes` bytes from /dev/zero. Normal-scheduled (E07 normal arm).
  Simulates blocking filesystem I/O on a normal scheduler.
  """
  def fs_read_bytes(_bytes), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Reads `bytes` bytes from /dev/zero. DirtyIo-scheduled (E07 dirty arm).
  Demonstrates correct scheduling for filesystem I/O.
  """
  def fs_read_bytes_dirty_io(_bytes), do: :erlang.nif_error(:nif_not_loaded)

  # ── Theme B: Failure Modes ───────────────────────────────────────────────────

  @doc """
  Triggers a Rust panic. Rustler's `catch_unwind` wrapper converts it to
  `{:error, :nif_panicked}` — the calling process survives (E08).
  """
  def panic_now, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Allocates `mb` MiB and leaks it (`mem::forget`). RSS grows indefinitely.
  Used by E09 to characterize native memory leak behavior.
  """
  def leak_memory_mb(_mb), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Allocates `mb` MiB and immediately drops it. Used by E10 to observe how
  the Erlang GC interacts with Rustler resources.
  """
  def make_resource(_mb), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Creates a mutex deadlock on a DirtyCpu thread. The Watchdog detects the
  timeout. Must run isolated (E11).
  """
  def deadlock, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Spawns `n` OS threads, each sleeping 30 seconds. Used by E12 to observe
  BEAM thread-count behavior under thread explosion.
  """
  def spawn_threads(_n), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Spawns a detached OS thread that runs for `seconds` seconds; the NIF
  returns immediately (E13). Demonstrates detached native thread lifecycle.
  """
  def detach_thread(_seconds), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Triggers a segmentation fault. Kills the OS process. Must run isolated
  (E14). Demonstrates that native segfaults crash the entire VM.
  """
  def segfault, do: :erlang.nif_error(:nif_not_loaded)

  # ── Theme D: Scale ────────────────────────────────────────────────────────────

  @doc """
  Allocates a binary of `mb` MiB and returns it across the NIF boundary.
  Used by E18 to measure large binary transfer overhead.
  """
  def large_binary_mb(_mb), do: :erlang.nif_error(:nif_not_loaded)

  # ── Theme E: Real-World ───────────────────────────────────────────────────────

  @doc """
  Simulates a PDF page-render workload (CPU-bound for `ms` ms). Normal-scheduled.
  Used by E21 (NIF arm). In production would call pdfium-render.
  """
  def pdf_work(_ms), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Same as `pdf_work/1` but DirtyCpu-scheduled (E21 dirty arm comparison).
  """
  def pdf_work_dirty(_ms), do: :erlang.nif_error(:nif_not_loaded)
end
