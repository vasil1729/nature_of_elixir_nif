defmodule Lab.Executor.Isolated do
  @moduledoc """
  Runs a crash experiment in a separate child BEAM (ADR 0002).

  Spawns `elixir` with the same scheduler flags as the parent, running
  the experiment via Lab.Runner. The child streams JSONL metrics to
  stdout; this executor parses them and broadcasts to PubSub so the
  UI's dashboard stays alive and shows the child's metrics in real time.

  When the child BEAM dies (segfault -> exit 11, OOM -> exit 137, etc.),
  the executor records the exit code and last metrics timestamp as
  evidence. The UI shows: "Child BEAM exited with code N at T+Xs."

  See docs/07_ui_architecture.md and ADR 0002.
  """

  require Logger

  @scheduler_flags ~w(+S 4:4 +SDcpu 4:4 +SDio 4:4 +A 10)

  @doc """
  Runs an isolated experiment. Returns {:ok, result} or {:error, reason}.

  The child BEAM runs:
    elixir --erl "+S 4:4 +SDcpu 4:4 +SDio 4:4 +A 10" -e "Lab.IsolatedRunner.run(:E14, params)"

  The child's stdout is parsed line by line for JSONL metrics, which are
  broadcast to PubSub. On exit, the exit code is recorded.
  """
  def run(config, params, opts \\ []) do
    exp_id = config.id
    data_path = Keyword.get(opts, :data_path, Lab.Core.default_data_path(exp_id))

    Logger.info("[Isolated] Spawning child BEAM for #{exp_id}")

    # Build the Elixir code the child will run
    params_json = Jason.encode!(params)
    child_code = """
      Application.ensure_all_started(:lab_core)
      Application.ensure_all_started(:lab_runner)
      Lab.IsolatedRunner.run(:#{exp_id}, #{params_json}, "#{data_path}")
    """

    # Spawn the child BEAM
    port = Port.open(
      {:spawn_executable, elixir_executable()},
      [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:args, @scheduler_flags ++ ["-e", child_code]}
      ]
    )

    # Collect output and broadcast metrics
    {exit_code, last_metrics} = collect_output(port, exp_id, System.monotonic_time(:millisecond))

    Logger.info("[Isolated] Child BEAM exited with code #{exit_code}")

    # Generate report from the child's JSONL files
    report = Lab.Core.Reporter.generate(exp_id,
      data_path: data_path,
      output_path: Keyword.get(opts, :output_path),
      exit_code: exit_code,
      params: params,
      config: config
    )

    {:ok, %{
      experiment_id: exp_id,
      exit_code: exit_code,
      report: report,
      data_path: data_path,
      last_metrics: last_metrics,
      isolated: true
    }}
  end

  defp collect_output(port, exp_id, start_ts) do
    receive do
      {^port, {:data, data}} ->
        # Parse each line as JSONL and broadcast to PubSub
        for line <- String.split(data, "\n", trim: true) do
          broadcast_line(line, exp_id)
        end

        collect_output(port, exp_id, start_ts)

      {^port, {:exit_status, code}} ->
        elapsed = div(System.monotonic_time(:millisecond) - start_ts, 1000)
        Logger.info("[Isolated] Child exited at T+#{elapsed}s with code #{code}")

        # Broadcast the crash event
        Phoenix.PubSub.broadcast(Lab.PubSub, Lab.Core.TelemetryPub.topic(),
          {:watchdog, %{event: :child_beam_exit, detail: %{exit_code: code, elapsed_s: elapsed}}, %{}}
        )

        {code, nil}
    after
      300_000 ->
        Logger.warning("[Isolated] Child BEAM timed out after 300s")
        Port.close(port)
        {:error, :timeout}
    end
  end

  defp broadcast_line(line, exp_id) do
    case Jason.decode(line, keys: :atoms) do
      {:ok, %{kind: :sampler, data: data}} ->
        Phoenix.PubSub.broadcast(Lab.PubSub, Lab.Core.TelemetryPub.topic(),
          {:sampler, data, %{experiment_id: exp_id}})

      {:ok, %{kind: :latency, data: data}} ->
        Phoenix.PubSub.broadcast(Lab.PubSub, Lab.Core.TelemetryPub.topic(),
          {:latency, data, %{experiment_id: exp_id}})

      {:ok, %{kind: :system, data: data}} ->
        Phoenix.PubSub.broadcast(Lab.PubSub, Lab.Core.TelemetryPub.topic(),
          {:system, data, %{experiment_id: exp_id}})

      {:ok, %{kind: :watchdog, data: data}} ->
        Phoenix.PubSub.broadcast(Lab.PubSub, Lab.Core.TelemetryPub.topic(),
          {:watchdog, data, %{experiment_id: exp_id}})

      _ ->
        :ok
    end
  end

  defp elixir_executable do
    System.find_executable("elixir") || "elixir"
  end
end
