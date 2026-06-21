defmodule Lab.Assertions do
  @moduledoc """
  Checks experiment results against declared thresholds.

  Each threshold in `config.exs` is either:
    * a `*_max` threshold (test fails if the metric exceeds it)
    * a `*_min` threshold (test fails if the metric doesn't reach it)
    * a boolean (`vm_alive: true` means the BEAM must survive)

  See docs/06_reproducibility_protocol.md and ADR 0004.
  """

  @doc """
  Checks all thresholds against the results map.

  Returns `{pass_count, fail_count, results_map}` where `results_map`
  is `%{threshold_name => boolean}`.
  """
  def check_all(results, thresholds) when is_map(results) and is_map(thresholds) do
    checked =
      Map.new(thresholds, fn {key, expected} ->
        actual = Map.get(results, key)
        passed = check_one(key, expected, actual)
        {key, passed}
      end)

    pass = Enum.count(checked, fn {_, v} -> v end)
    fail = map_size(checked) - pass
    {pass, fail, checked}
  end

  @doc "Returns true if all assertions passed."
  def all_passed?({_pass, fail, _checked}), do: fail == 0

  defp check_one(_key, true, actual) when is_boolean(actual), do: actual == true
  defp check_one(_key, false, actual) when is_boolean(actual), do: actual == false

  defp check_one(key, expected, actual) when is_number(expected) and is_number(actual) do
    key_str = to_string(key)
    cond do
      # _max at end or followed by a unit suffix (e.g. latency_p99_max_ms)
      String.ends_with?(key_str, "_max") or String.contains?(key_str, "_max_") ->
        actual <= expected

      String.ends_with?(key_str, "_min") or String.contains?(key_str, "_min_") ->
        actual >= expected

      true ->
        actual == expected
    end
  end

  defp check_one(_key, expected, actual), do: actual == expected

  @doc """
  Extracts metric values from the Reporter's summary into a flat map
  matching threshold keys.

  Converts e.g. `summary.sampler.normal_util_max` (a float 0..1) into
  `:normal_sched_util_max` (a percentage 0..100) to match config.exs
  threshold keys.
  """
  def extract_results(summary, opts \\ []) do
    exit_code = Keyword.get(opts, :exit_code, 0)
    s = summary.sampler
    l = summary.latency
    sys = summary.system

    %{
      vm_alive: exit_code == 0,
      vm_crashed: exit_code != 0,
      normal_sched_util_max: to_percent(s.normal_util_max),
      normal_sched_util_mean: to_percent(s.normal_util_mean),
      dirty_sched_util_max: to_percent(s.dirty_cpu_util_max),
      dirty_sched_util_min: to_percent(s.dirty_cpu_util_max),
      latency_p99_max_ms: to_ms(l.p99_max_us),
      latency_p50_max_ms: to_ms(l.p50_max_us),
      rss_max_mb: sys.rss_max_mb,
      run_queue_max: s.run_queue_max,
      process_count_min: s.process_count_max
    }
  end

  defp to_percent(nil), do: nil
  defp to_percent(f) when is_float(f), do: Float.round(f * 100, 1)
  defp to_percent(i) when is_integer(i), do: i * 100

  defp to_ms(nil), do: nil
  defp to_ms(us) when is_number(us), do: Float.round(us / 1000, 2)
end
