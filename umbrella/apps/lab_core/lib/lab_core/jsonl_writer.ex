defmodule Lab.Core.JsonlWriter do
  @moduledoc """
  Append-only JSONL writer for probe output.

  Each probe owns a file handle to `data/<experiment_id>/<name>.jsonl`.
  Lines are written with `:unicode` encoding and a trailing newline.
  """

  use GenServer

  @doc "Starts a writer for `path` (full file path)."
  def start_link(path) when is_binary(path) do
    GenServer.start_link(__MODULE__, path)
  end

  @doc "Appends one struct (Jason.Encoder) or map as a JSONL line."
  def write(pid, struct_or_map) when is_pid(pid) do
    GenServer.cast(pid, {:write, struct_or_map})
  end

  @doc "Synchronously flushes and closes the file."
  def close(pid) when is_pid(pid) do
    GenServer.call(pid, :close)
  end

  @impl true
  def init(path) do
    File.mkdir_p!(Path.dirname(path))
    {:ok, file} = File.open(path, [:append, :utf8])
    {:ok, %{file: file, path: path}}
  end

  @impl true
  def handle_cast({:write, data}, %{file: file} = state) do
    line = Jason.encode!(data) <> "\n"
    IO.binwrite(file, line)
    {:noreply, state}
  end

  @impl true
  def handle_call(:close, _from, %{file: file} = state) do
    File.close(file)
    {:reply, :ok, %{state | file: nil}}
  end

  @impl true
  def terminate(_reason, %{file: file}) when not is_nil(file) do
    File.close(file)
  end
end
