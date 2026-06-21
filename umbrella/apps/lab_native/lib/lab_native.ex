defmodule Lab.Native do
  @moduledoc """
  Rustler NIF interface for the BEAM Characterization Lab.

  This module loads the `lab_native` Rust crate and exposes its NIFs.
  Each NIF has Normal and Dirty variants (where applicable) — see
  docs/02_nif_taxonomy_rustler.md and docs/09_architecture.md.

  ## NIFs

  | NIF | Schedule | Description |
  |-----|----------|-------------|
  | `hello/0` | Normal | Smoke test — returns `:ok` |
  | `cpu_work_ms/1` | Normal | CPU-bound work for `ms` milliseconds (E01) |
  | `cpu_work_ms_dirty/1` | DirtyCpu | Same, dirty-scheduled (E02) |

  NIFs are added per-experiment (see docs/10_development_guide.md).
  """

  use Rustler,
    otp_app: :lab_native,
    crate: :lab_native

  # Fallback definitions — replaced by NIFs when the crate loads.
  # If the .so isn't found, these raise with a helpful message.

  @doc "Smoke-test NIF. Returns `:ok` if the crate loaded."
  def hello, do: :erlang.nif_error(:nif_not_loaded)

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
end
