defmodule Lab.Core.Reporter do
  @moduledoc """
  Renders `report.md` for an experiment from JSONL metrics + assertion
  results.

  Pure module — no state. Call `generate/2` after a run completes.

  Output path: `experiments/<slug>/report.md` (or a custom path).

  See docs/08_final_report_rubric.md for the evidence-block format.
  """

  @doc """
  Generates a report for an experiment run.

  ## Arguments

    * `experiment_id` — atom (e.g. `:E02`)
    * `opts` — keyword list:
      * `:data_path`   — where JSONL files live (default: `data/<id>/`)
      * `:output_path` — where to write report.md
      * `:assertions`  — map of assertion results from `Lab.Assertions`
      * `:params`      — map of params used for this run
      * `:exit_code`   — integer (0 = clean, 11 = SIGSEGV, 137 = OOM)
      * `:config`      — the experiment's `config.exs` map (for hypothesis etc.)

  """
  def generate(experiment_id, opts) do
    data_path = Keyword.get(opts, :data_path, Lab.Core.default_data_path(experiment_id))
    output_path = Keyword.get(opts, :output_path)
    assertions = Keyword.get(opts, :assertions, %{})
    params = Keyword.get(opts, :params, %{})
    exit_code = Keyword.get(opts, :exit_code, 0)
    config = Keyword.get(opts, :config, %{})

    summary = summarize_jsonl(data_path)
    status = run_status(exit_code, assertions)

    body = render_report(experiment_id, config, params, summary, assertions, exit_code, status)

    if output_path do
      File.mkdir_p!(Path.dirname(output_path))
      File.write!(output_path, body)
    end

    body
  end

  defp run_status(exit_code, assertions) do
    cond do
      exit_code != 0 -> "crashed (exit #{exit_code})"
      Enum.any?(assertions, fn {_, v} -> v == false end) -> "failed"
      true -> "passed"
    end
  end

  defp summarize_jsonl(data_path) do
    %{
      sampler: summarize_sampler(data_path),
      latency: summarize_latency(data_path),
      system: summarize_system(data_path),
      watchdog: summarize_watchdog(data_path)
    }
  end

  defp summarize_sampler(data_path) do
    read_jsonl(Path.join(data_path, "sampler.jsonl"), fn rows ->
      case rows do
        [] ->
          %{
            rows: 0,
            normal_util_max: nil,
            normal_util_mean: nil,
            dirty_cpu_util_max: nil,
            run_queue_max: 0,
            run_queue_mean: 0,
            process_count_max: 0,
            beam_memory_max: nil,
            first_ts: nil,
            last_ts: nil
          }

        _ ->
          normal_utils = rows |> Enum.map(& &1.sched_util) |> Enum.reject(&is_nil/1)
          dirty_cpu_utils = rows |> Enum.map(& &1.dirty_cpu_util) |> Enum.reject(&is_nil/1)
          rqs = rows |> Enum.map(& &1.run_queue) |> Enum.reject(&is_nil/1)

          %{
            rows: length(rows),
            normal_util_max: max_util(normal_utils),
            normal_util_mean: mean_util(normal_utils),
            dirty_cpu_util_max: max_util(dirty_cpu_utils),
            run_queue_max: Enum.max(rqs, &>=/2, fn -> 0 end),
            run_queue_mean: Enum.sum(rqs) / max(length(rqs), 1),
            process_count_max: rows |> Enum.map(& &1.process_count) |> Enum.reject(&is_nil/1) |> Enum.max(&>=/2, fn -> 0 end),
            beam_memory_max: rows |> Enum.map(& &1.beam_total_memory) |> Enum.reject(&is_nil/1) |> Enum.max(&>=/2, fn -> 0 end),
            first_ts: List.first(rows) && List.first(rows).ts,
            last_ts: List.last(rows) && List.last(rows).ts
          }
      end
    end)
  end

  defp summarize_latency(data_path) do
    read_jsonl(Path.join(data_path, "latency.jsonl"), fn rows ->
      windows = Enum.filter(rows, &Map.has_key?(&1, :p99_us))

      case windows do
        [] ->
          %{rows: length(rows), windows: 0, p99_max_us: nil, p50_max_us: nil}

        _ ->
          p99s = windows |> Enum.map(& &1.p99_us) |> Enum.reject(&is_nil/1)
          p50s = windows |> Enum.map(& &1.p50_us) |> Enum.reject(&is_nil/1)

          %{
            rows: length(rows),
            windows: length(windows),
            p99_max_us: Enum.max(p99s, &>=/2, fn -> 0 end),
            p50_max_us: Enum.max(p50s, &>=/2, fn -> 0 end)
          }
      end
    end)
  end

  defp summarize_system(data_path) do
    read_jsonl(Path.join(data_path, "system.jsonl"), fn rows ->
      case rows do
        [] ->
          %{rows: 0, rss_max_kb: 0, rss_max_mb: 0, threads_max: 0}

        _ ->
          rss = rows |> Enum.map(& &1.rss_kb) |> Enum.reject(&is_nil/1)
          threads = rows |> Enum.map(& &1.threads) |> Enum.reject(&is_nil/1)

          rss_max = Enum.max(rss, &>=/2, fn -> 0 end)

          %{
            rows: length(rows),
            rss_max_kb: rss_max,
            rss_max_mb: div(rss_max, 1024),
            threads_max: Enum.max(threads, &>=/2, fn -> 0 end)
          }
      end
    end)
  end

  defp summarize_watchdog(data_path) do
    read_jsonl(Path.join(data_path, "watchdog.jsonl"), fn rows ->
      events = rows |> Enum.map(& &1.event) |> Enum.reject(&is_nil/1)
      %{
        rows: length(rows),
        events: events,
        killed: :time_budget_exceeded in events or :memory_guard in events
      }
    end)
  end

  defp read_jsonl(path, fun) do
    if File.exists?(path) do
      rows = read_jsonl_rows(path)
      fun.(rows)
    else
      fun.([])
    end
  end

  defp read_jsonl_rows(path) do
    File.read!(path)
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      Jason.decode!(line, keys: :atoms)
    end)
  end

  defp max_util([]), do: 0.0
  defp max_util(utils), do: utils |> Enum.flat_map(fn list when is_list(list) -> Enum.map(list, fn {_, u} -> u end); _ -> [] end) |> Enum.max(&>=/2, fn -> 0.0 end)

  defp mean_util([]), do: 0.0
  defp mean_util(utils) do
    all = utils |> Enum.flat_map(fn list when is_list(list) -> Enum.map(list, fn {_, u} -> u end); _ -> [] end)
    if all == [], do: 0.0, else: Enum.sum(all) / length(all)
  end

  defp render_report(experiment_id, config, params, summary, assertions, exit_code, status) do
    [
      "# #{experiment_id} — Run Report",
      "",
      "**Status:** #{status}  ",
      "**Exit code:** #{exit_code}  ",
      "**Generated:** #{DateTime.utc_now() |> DateTime.to_iso8601()}",
      "",
      "## Parameters",
      "",
      params_table(params),
      "",
      "## Summary Metrics",
      "",
      summary_table(summary),
      "",
      "## Assertions",
      "",
      assertions_table(assertions),
      "",
      "## Evidence",
      "",
      "- Sampler metrics: `data/#{experiment_id}/sampler.jsonl` (#{summary.sampler.rows} rows)",
      "- Latency metrics: `data/#{experiment_id}/latency.jsonl` (#{summary.latency.rows} rows)",
      "- System metrics:  `data/#{experiment_id}/system.jsonl` (#{summary.system.rows} rows)",
      "- Watchdog events: `data/#{experiment_id}/watchdog.jsonl` (#{summary.watchdog.rows} rows)",
      "",
      "## Conclusion",
      "",
      if config[:hypothesis] do
        "**Hypothesis:** #{config.hypothesis}"
      else
        "<to be filled from experiment README>"
      end,
      "",
      "<fill in: was the hypothesis confirmed or refuted? cite specific metrics above>"
    ]
    |> Enum.join("\n")
  end

  defp params_table(params) when map_size(params) == 0, do: "_(defaults used)_"

  defp params_table(params) do
    rows =
      params
      |> Enum.map(fn {k, v} -> "| #{k} | #{v} |" end)
      |> Enum.join("\n")

    "| Param | Value |\n|-------|-------|\n#{rows}"
  end

  defp summary_table(summary) do
    s = summary.sampler
    l = summary.latency
    sys = summary.system

    "| Metric | Value |\n|--------|-------|\n" <>
      "| Sampler rows | #{s.rows} |\n" <>
      "| Normal util max | #{format_util(s.normal_util_max)} |\n" <>
      "| Normal util mean | #{format_util(s.normal_util_mean)} |\n" <>
      "| Dirty CPU util max | #{format_util(s.dirty_cpu_util_max)} |\n" <>
      "| Run queue max | #{s.run_queue_max} |\n" <>
      "| Process count max | #{s.process_count_max} |\n" <>
      "| BEAM memory max | #{format_bytes(s.beam_memory_max)} |\n" <>
      "| Latency rows | #{l.rows} |\n" <>
      "| Latency p99 max | #{format_us(l.p99_max_us)} |\n" <>
      "| Latency p50 max | #{format_us(l.p50_max_us)} |\n" <>
      "| RSS max | #{sys.rss_max_mb || 0} MB |\n" <>
      "| Threads max | #{sys.threads_max} |"
  end

  defp assertions_table(assertions) when map_size(assertions) == 0, do: "_(no assertions declared)_"

  defp assertions_table(assertions) do
    rows =
      assertions
      |> Enum.map(fn {k, v} -> "| #{k} | #{if v, do: "pass", else: "fail"} |" end)
      |> Enum.join("\n")

    "| Assertion | Result |\n|-----------|--------|\n#{rows}"
  end

  defp format_util(nil), do: "n/a"
  defp format_util(u), do: "#{Float.round(u * 100, 1)}%"

  defp format_bytes(nil), do: "n/a"
  defp format_bytes(b), do: "#{div(b, 1024 * 1024)} MB"

  defp format_us(nil), do: "n/a"
  defp format_us(us), do: "#{Float.round(us / 1000, 2)} ms"
end
