defmodule Lab.Port do
  @moduledoc """
  Port interface for the BEAM Characterization Lab.

  Communicates with the `lab_port` Rust binary via stdin/stdout JSON.
  See docs/09_architecture.md for the protocol spec.

  This is a stub; commit 8 fills in the binary and port management.
  """

  @doc false
  def hello, do: :ok
end
