defmodule Lab.Core.SystemProbe do
  @moduledoc """
  Polls OS-level process metrics from /proc at a pinned interval (500ms).

  Records RSS (KB), thread count, file descriptor count, and CPU jiffies
  for the current BEAM process (`os getpid()`).

  Emits `[:lab, :system, :sample]` telemetry with a `Lab.Core.SystemMetrics`
  struct and writes JSONL to `data/<id>/system.jsonl`.

  Linux-only. On non-Linux, emits nil values (the lab is Linux-targeted).
  See docs/03_measurement_protocol.md.
  """

  use GenServer

  @default_interval_ms 500

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    exp_id = Keyword.fetch!(opts, :experiment_id)
    data_path = Keyword.fetch!(opts, :data_path)

    {:ok, writer} = Lab.Core.JsonlWriter.start_link(Path.join(data_path, "system.jsonl"))

    state = %{interval: interval, exp_id: exp_id, writer: writer, pid: pid_string()}

    schedule_next(state)
    {:ok, state}
  end

  defp schedule_next(%{interval: interval}) do
    Process.send_after(self(), :sample, interval)
  end

  @impl true
  def handle_info(:sample, state) do
    sample = take_sample(state.pid)
    Lab.Core.JsonlWriter.write(state.writer, sample)

    :telemetry.execute(
      [:lab, :system, :sample],
      %{metrics: sample},
      %{experiment_id: state.exp_id}
    )

    schedule_next(state)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{writer: writer}) do
    Lab.Core.JsonlWriter.close(writer)
  end

  defp pid_string do
    :os.getpid() |> to_string()
  end

  defp take_sample(pid_str) do
    %Lab.Core.SystemMetrics{
      ts: Lab.Core.monotonic_ms(),
      rss_kb: read_rss_kb(pid_str),
      threads: read_threads(pid_str),
      fds: read_fds(pid_str),
      cpu_user_jiffies: read_cpu_jiffies(pid_str, 14),
      cpu_system_jiffies: read_cpu_jiffies(pid_str, 15)
    }
  end

  # /proc/<pid>/status -> VmRSS:  12345 kB
  defp read_rss_kb(pid_str) do
    case File.read("/proc/#{pid_str}/status") do
      {:ok, content} ->
        Regex.run(~r/^VmRSS:\s+(\d+)\s+kB$/m, content, capture: :all_but_first)
        |> case do
          [val] -> String.to_integer(val)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # /proc/<pid>/status -> Threads: 42
  defp read_threads(pid_str) do
    case File.read("/proc/#{pid_str}/status") do
      {:ok, content} ->
        Regex.run(~r/^Threads:\s+(\d+)$/m, content, capture: :all_but_first)
        |> case do
          [val] -> String.to_integer(val)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # /proc/<pid>/fd/ -> count entries
  defp read_fds(pid_str) do
    case File.ls("/proc/#{pid_str}/fd") do
      {:ok, entries} -> length(entries)
      _ -> nil
    end
  end

  # /proc/<pid>/stat -> field 14 (utime) or 15 (stime) in jiffies
  defp read_cpu_jiffies(pid_str, field_index) do
    case File.read("/proc/#{pid_str}/stat") do
      {:ok, content} ->
        # The stat file has fields split by space, but comm (field 2) may
        # contain spaces if wrapped in parens. Strip the comm field first.
        stripped =
          Regex.replace(~r/^\d+\s+\(.*?\)\s/, content, "0 (comm) ")

        parts = String.split(stripped, " ", trim: true)

        Enum.at(parts, field_index - 1)
        |> case do
          nil -> nil
          val -> String.to_integer(val)
        end

      _ ->
        nil
    end
  end
end
