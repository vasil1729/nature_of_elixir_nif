defmodule Lab.Native do
  @moduledoc """
  Rustler NIF interface for the BEAM Characterization Lab.

  This module loads the `lab_native` Rust crate and exposes its NIFs.
  Each NIF has Normal and Dirty variants (where applicable) — see
  docs/02_nif_taxonomy_rustler.md and docs/09_architecture.md.

  NIFs are added per-experiment (see docs/10_development_guide.md).
  This is a stub; commit 7 fills in the crate and first NIFs.
  """

  @doc false
  def hello, do: :ok
end
