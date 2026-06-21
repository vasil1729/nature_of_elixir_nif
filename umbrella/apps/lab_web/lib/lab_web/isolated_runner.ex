defmodule Lab.IsolatedRunner do
  @moduledoc """
  Runs inside the isolated child BEAM (spawned by Lab.Executor.Isolated).

  Starts lab_core probes, executes the workload, and writes JSONL metrics
  to stdout (parsed by the parent's Isolated executor). On crash
  (segfault, abort), the child dies — the parent records the exit code.

  This module is loaded in the child BEAM via:
    elixir --erl "+S 4:4 ..." -e "Lab.IsolatedRunner.run(:E14, params, path)"

  See docs/07_ui_architecture.md and ADR 0002.
  """

  require Logger

  @doc """
  Runs an experiment in the child BEAM. Metrics are written to stdout
  as JSONL lines: {\"kind\":\"sampler\",\"data\":{...}}

  The parent BEAM parses these and broadcasts to PubSub.
  """
  def run(exp_id, params, data_path) do
    config = Lab.ExperimentConfig.load!(exp_id)
    File.mkdir_p!(data_path)

    # Redirect lab_core telemetry to stdout instead of PubSub
    Application.put_env(:lab_core, :stdout_metrics, true)

    # Start probes
    {:ok, sup} = Lab.Core.start_probes(
      experiment_id: exp_id,
      data_path: data_path,
      time_budget_ms: Map.get(config, :time_budget_ms, 120_000)
    )

    # Also attach a stdout telemetry handler
    attach_stdout_handler(exp_id)

    Logger.info("IsolatedRunner: starting #{exp_id}")

    # Execute the workload
    {exit_code, _result} = execute_workload(config, params)

    # Stop probes
    Lab.Core.stop_probes(sup)

    Logger.info("IsolatedRunner: done with exit code #{exit_code}")

    # Exit with the workload's exit code
    System.halt(exit_code)
  end

  defp execute_workload(config, params) do
    cond do
      config[:nif] ->
        {module, function, _arity} = config.nif
        args = nif_args(function, params)
        try do
          result = apply(module, function, args)
          {0, result}
        rescue
          _e -> {1, :exception}
        catch
          :exit, _reason -> {1, :exit}
        end

      config[:port_cmd] ->
        opts = Map.to_list(params)
        case Lab.Port.call(config.port_cmd, opts) do
          {:ok, resp} -> {0, resp}
          {:error, {:port_crashed, code}} -> {code, :port_crashed}
          {:error, _} -> {1, :error}
        end

      true ->
        {0, :no_workload}
    end
  end

  defp nif_args(function, params) do
    cond do
      function in [:cpu_work_ms, :cpu_work_ms_dirty] -> [Map.get(params, :duration_ms, 30_000)]
      function in [:sleep_for_ms, :sleep_for_ms_dirty_io] -> [Map.get(params, :duration_ms, 60_000)]
      function == :infinite_loop -> []
      function == :panic_now -> []
      function == :leak_memory_mb -> [Map.get(params, :mb, 100)]
      function == :large_binary_mb -> [Map.get(params, :mb, 10)]
      function == :spawn_threads -> [Map.get(params, :count, 100)]
      function == :segfault -> []
      true -> []
    end
  end

  defp attach_stdout_handler(exp_id) do
    events = [
      {[:lab, :sampler, :sample], :sampler},
      {[:lab, :latency, :window], :latency},
      {[:lab, :system, :sample], :system},
      {[:lab, :watchdog, :event], :watchdog}
    ]

    for {event, kind} <- events do
      :telemetry.attach(
        {__MODULE__, kind, exp_id},
        event,
        fn _event, measurements, _meta, %{kind: k} ->
          data = Map.from_struct(measurements.metrics)
          line = Jason.encode!(%{kind: k, data: data})
          IO.puts(line)
        end,
        %{kind: kind}
      )
    end
  end
end
