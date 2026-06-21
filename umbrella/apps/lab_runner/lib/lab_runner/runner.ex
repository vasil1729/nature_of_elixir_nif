defmodule Lab.Runner do
  @moduledoc """
  Orchestrates a single experiment run: load config → start probes →
  run workload → stop probes → check assertions → generate report.

  Called by both the CLI (`scripts/run_experiment.sh`) and the UI's
  executor (`Lab.Executor.InProcess`). See docs/09_architecture.md.
  """

  require Logger

  @doc """
  Runs an experiment by ID.

  ## Options

    * `:params` — override default params (e.g. `%{duration_ms: 60_000}`)
    * `:data_path` — override JSONL output path
    * `:output_path` — override report.md output path

  Returns `{:ok, results_map}` on success or `{:error, reason}` on failure.
  `results_map` includes `:summary`, `:assertions`, `:exit_code`, `:report`.
  """
  def run(id, opts \\ []) when is_atom(id) or is_binary(id) do
    config = Lab.ExperimentConfig.load!(id)
    run_with_config(config, opts)
  end

  @doc "Runs an experiment with a pre-loaded config map."
  def run_with_config(config, opts \\ []) do
    exp_id = config.id
    params = Map.merge(default_params(config), Keyword.get(opts, :params, %{}))
    data_path = Keyword.get(opts, :data_path, Lab.Core.default_data_path(exp_id))
    output_path = Keyword.get(opts, :output_path, report_path(config))

    Logger.info("[Runner] Starting #{exp_id} with params=#{inspect(params)}")

    # Start instrumentation probes
    {:ok, sup} = Lab.Core.start_probes(
      experiment_id: exp_id,
      data_path: data_path,
      time_budget_ms: Map.get(config, :time_budget_ms, 120_000)
    )

    # Execute the workload
    {exit_code, work_result} = execute_workload(config, params)

    # Stop probes (flushes JSONL)
    Lab.Core.stop_probes(sup)

    # Generate report
    summary = summarize_from_jsonl(data_path)
    results = Lab.Assertions.extract_results(summary, exit_code: exit_code)
    {pass, fail, assertion_map} = Lab.Assertions.check_all(results, config.thresholds || %{})

    report = Lab.Core.Reporter.generate(exp_id,
      data_path: data_path,
      output_path: output_path,
      assertions: assertion_map,
      params: params,
      exit_code: exit_code,
      config: config
    )

    Logger.info("[Runner] #{exp_id} done: #{pass} pass, #{fail} fail, exit #{exit_code}")

    {:ok, %{
      experiment_id: exp_id,
      summary: summary,
      results: results,
      assertions: assertion_map,
      assertion_pass: pass,
      assertion_fail: fail,
      exit_code: exit_code,
      work_result: work_result,
      report: report,
      data_path: data_path,
      report_path: output_path
    }}
  end

  defp execute_workload(config, params) do
    cond do
      config[:nif] ->
        execute_nif(config.nif, params)

      config[:port_cmd] ->
        execute_port(config.port_cmd, params)

      config[:workload] ->
        # Custom workload function
        config.workload.(params)

      true ->
        Logger.warning("[Runner] No nif/port_cmd/workload defined for #{config.id}")
        {0, :no_workload}
    end
  end

  defp execute_nif({module, function, _arity}, params) do
    args = nif_args(function, params)

    try do
      result = apply(module, function, args)
      {0, result}
    rescue
      e ->
        Logger.error("[Runner] NIF exception: #{inspect(e)}")
        {1, {:exception, e}}
    catch
      :exit, reason ->
        Logger.error("[Runner] NIF exit: #{inspect(reason)}")
        {1, {:exit, reason}}
    end
  end

  defp nif_args(function, params) do
    # Map common param names to function arguments by convention.
    # Each experiment's config can override with a :nif_args_fn.
    cond do
      function in [:cpu_work_ms, :cpu_work_ms_dirty] ->
        [Map.get(params, :duration_ms, 30_000)]

      function in [:sleep_for_ms, :sleep_for_ms_dirty_io] ->
        [Map.get(params, :duration_ms, 60_000)]

      function == :infinite_loop ->
        []

      function == :panic_now ->
        []

      function == :leak_memory_mb ->
        [Map.get(params, :mb, 100)]

      function == :large_binary_mb ->
        [Map.get(params, :mb, 10)]

      function == :spawn_threads ->
        [Map.get(params, :count, 100)]

      true ->
        # Fall back to params as positional args if it's a list
        case Map.get(params, :args, []) do
          args when is_list(args) -> args
          _ -> []
        end
    end
  end

  defp execute_port(cmd, params) do
    opts = Map.to_list(params)
    case Lab.Port.call(cmd, opts) do
      {:ok, resp} -> {0, resp}
      {:error, {:port_crashed, code}} -> {code, :port_crashed}
      {:error, reason} -> {1, {:error, reason}}
    end
  end

  defp default_params(config) do
    config
    |> Map.get(:params, %{})
    |> Map.new(fn {key, spec} -> {key, spec[:default]} end)
  end

  defp report_path(config) do
    Path.join([config.__dir__ || "experiments/#{config.id}", "report.md"])
  end

  defp summarize_from_jsonl(data_path) do
    %{
      sampler: read_sampler_summary(data_path),
      latency: read_latency_summary(data_path),
      system: read_system_summary(data_path),
      watchdog: read_watchdog_summary(data_path)
    }
  end

  defp read_sampler_summary(data_path) do
    path = Path.join(data_path, "sampler.jsonl")

    if File.exists?(path) do
      rows = read_jsonl(path)
      normal_utils = rows |> Enum.map(& &1[:sched_util]) |> Enum.reject(&is_nil/1)

      %{
        rows: length(rows),
        normal_util_max: max_util(normal_utils),
        normal_util_mean: mean_util(normal_utils),
        dirty_cpu_util_max: max_util(rows |> Enum.map(& &1[:dirty_cpu_util]) |> Enum.reject(&is_nil/1)),
        run_queue_max: rows |> Enum.map(& &1[:run_queue]) |> Enum.reject(&is_nil/1) |> Enum.max(&>=/2, fn -> 0 end),
        process_count_max: rows |> Enum.map(& &1[:process_count]) |> Enum.reject(&is_nil/1) |> Enum.max(&>=/2, fn -> 0 end),
        beam_memory_max: rows |> Enum.map(& &1[:beam_total_memory]) |> Enum.reject(&is_nil/1) |> Enum.max(&>=/2, fn -> 0 end)
      }
    else
      %{rows: 0, normal_util_max: nil, normal_util_mean: nil, dirty_cpu_util_max: nil,
        run_queue_max: 0, process_count_max: 0, beam_memory_max: nil}
    end
  end

  defp read_latency_summary(data_path) do
    path = Path.join(data_path, "latency.jsonl")

    if File.exists?(path) do
      rows = read_jsonl(path)
      windows = Enum.filter(rows, &Map.has_key?(&1, :p99_us))
      p99s = windows |> Enum.map(& &1[:p99_us]) |> Enum.reject(&is_nil/1)

      %{
        rows: length(rows),
        windows: length(windows),
        p99_max_us: if(p99s == [], do: nil, else: Enum.max(p99s)),
        p50_max_us: nil
      }
    else
      %{rows: 0, windows: 0, p99_max_us: nil, p50_max_us: nil}
    end
  end

  defp read_system_summary(data_path) do
    path = Path.join(data_path, "system.jsonl")

    if File.exists?(path) do
      rows = read_jsonl(path)
      rss = rows |> Enum.map(& &1[:rss_kb]) |> Enum.reject(&is_nil/1)

      %{
        rows: length(rows),
        rss_max_kb: Enum.max(rss, &>=/2, fn -> 0 end),
        rss_max_mb: div(Enum.max(rss, &>=/2, fn -> 0 end), 1024),
        threads_max: rows |> Enum.map(& &1[:threads]) |> Enum.reject(&is_nil/1) |> Enum.max(&>=/2, fn -> 0 end)
      }
    else
      %{rows: 0, rss_max_kb: 0, rss_max_mb: 0, threads_max: 0}
    end
  end

  defp read_watchdog_summary(data_path) do
    path = Path.join(data_path, "watchdog.jsonl")

    if File.exists?(path) do
      rows = read_jsonl(path)
      events = rows |> Enum.map(& &1[:event]) |> Enum.reject(&is_nil/1)
      %{rows: length(rows), events: events, killed: :time_budget_exceeded in events}
    else
      %{rows: 0, events: [], killed: false}
    end
  end

  defp read_jsonl(path) do
    File.read!(path)
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!(&1, keys: :atoms))
  end

  defp max_util([]), do: nil
  defp max_util(utils) do
    utils
    |> Enum.flat_map(fn
      list when is_list(list) -> Enum.map(list, fn {_, u} -> u end)
      _ -> []
    end)
    |> Enum.max(fn -> 0.0 end)
  end

  defp mean_util([]), do: nil
  defp mean_util(utils) do
    all = utils |> Enum.flat_map(fn
      list when is_list(list) -> Enum.map(list, fn {_, u} -> u end)
      _ -> []
    end)

    if all == [], do: 0.0, else: Enum.sum(all) / length(all)
  end
end
