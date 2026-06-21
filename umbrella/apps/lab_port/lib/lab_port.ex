defmodule Lab.Port do
  @moduledoc """
  Port interface for the BEAM Characterization Lab.

  Communicates with the `lab_port` Rust binary via stdin/stdout JSON.
  See docs/09_architecture.md for the protocol spec.

  Unlike NIFs, a port process crash doesn't kill the BEAM — the port
  owner receives an exit signal. This is the crash-isolation advantage
  tested by E17 and used by E21's Port arm.

  ## Commands

  | Command | Args | Description |
  |---------|------|-------------|
  | `cpu_work` | `ms` | CPU-bound work for `ms` milliseconds |
  | `quit` | — | Clean shutdown |

  Commands are added per-experiment (see docs/10_development_guide.md).
  """

  @doc """
  Calls the port binary with a command and returns the response.

  ## Options

    * `:ms` — milliseconds for cpu_work (default: 1000)
    * `:timeout` — call timeout in ms (default: 120_000)

  ## Examples

      iex> Lab.Port.call("cpu_work", ms: 100)
      {:ok, %{"id" => "...", "ok" => true, "duration_ms" => 101}}

      iex> Lab.Port.call("segfault")
      {:error, :port_crashed}
  """
  def call(cmd, opts \\ []) do
    id = generate_id()
    req = Jason.encode!(Map.merge(%{"cmd" => cmd, "id" => id}, opts_to_map(opts)))

    case open_port() do
      {:ok, port} ->
        send(port, {self(), {:command, req <> "\n"}})
        result = wait_response(port, id, Keyword.get(opts, :timeout, 120_000))
        Port.close(port)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Calls cpu_work and returns the elapsed duration in ms."
  def cpu_work(ms, opts \\ []) do
    case call("cpu_work", Keyword.merge(opts, ms: ms)) do
      {:ok, %{"ok" => true, "duration_ms" => duration_ms}} -> {:ok, duration_ms}
      {:ok, %{"ok" => false, "error" => e}} -> {:error, e}
      {:error, reason} -> {:error, reason}
    end
  end

  defp open_port do
    binary = port_binary_path()

    if File.exists?(binary) do
      port = Port.open({:spawn_executable, binary}, [
        :binary,
        :exit_status,
        {:args, []}
      ])
      {:ok, port}
    else
      {:error, {:binary_not_found, binary}}
    end
  end

  defp wait_response(port, id, timeout) do
    receive do
      {^port, {:data, data}} ->
        # The port sends data as binaries; split on newlines to find lines
        case data |> String.split("\n", trim: true) do
          [line | _] ->
            case Jason.decode(line) do
              {:ok, %{"id" => ^id} = resp} -> {:ok, resp}
              {:ok, _resp} -> wait_response(port, id, timeout)
              {:error, _} -> wait_response(port, id, timeout)
            end

          [] ->
            wait_response(port, id, timeout)
        end

      {^port, {:exit_status, code}} ->
        {:error, {:port_crashed, code}}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  defp port_binary_path do
    :code.priv_dir(:lab_port) |> Path.join("native/lab_port")
  end

  defp generate_id do
    :erlang.unique_integer([:positive]) |> to_string()
  end

  defp opts_to_map(opts) do
    opts
    |> Enum.into(%{})
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
  end
end
