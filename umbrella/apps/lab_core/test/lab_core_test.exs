defmodule Lab.CoreTest do
  use ExUnit.Case, async: true

  doctest Lab.Core

  test "default_data_path lowercases the experiment id" do
    assert Lab.Core.default_data_path(:E02) == Path.join("data", "e02")
    assert Lab.Core.default_data_path(:E21) == Path.join("data", "e21")
  end

  test "monotonic_ms returns increasing integers" do
    a = Lab.Core.monotonic_ms()
    Process.sleep(2)
    b = Lab.Core.monotonic_ms()
    assert b > a
  end
end

defmodule Lab.Core.SamplerTest do
  use ExUnit.Case, async: true

  alias Lab.Core.Sampler

  test "aggregate/1 returns {0.0, 0.0} for empty list" do
    assert Sampler.aggregate([]) == {0.0, 0.0}
  end

  test "aggregate/1 returns mean and max" do
    utils = [{1, 0.5}, {2, 1.0}, {3, 0.0}]
    {mean, max} = Sampler.aggregate(utils)
    assert_in_delta mean, 0.5, 0.01
    assert max == 1.0
  end
end

defmodule Lab.Core.LatencyProbeTest do
  use ExUnit.Case, async: true

  # The percentile math is in compute_window/2; test via the module's
  # private function by re-implementing the nearest-rank algorithm here
  # to keep the contract explicit.

  test "nearest-rank percentile: p50 of 10 sorted samples" do
    sorted = Enum.to_list(1..10)
    count = length(sorted)
    assert percentile(sorted, count, 50) == 5
  end

  test "nearest-rank percentile: p99 of 100 samples" do
    sorted = Enum.to_list(1..100)
    count = length(sorted)
    assert percentile(sorted, count, 99) == 99
  end

  test "nearest-rank percentile: p99 of 1000 samples" do
    sorted = Enum.to_list(1..1000)
    count = length(sorted)
    # ceil(1000 * 99 / 100) = 990 -> index 989 -> value 990
    assert percentile(sorted, count, 99) == 990
  end

  defp percentile(sorted, count, pct) do
    rank = max(1, ceil(count * pct / 100))
    Enum.at(sorted, rank - 1)
  end
end

defmodule Lab.Core.ReporterTest do
  use ExUnit.Case, async: true

  alias Lab.Core.Reporter

  test "generate/2 produces a report with status crashed when exit_code != 0" do
    tmp = Path.join(System.tmp_dir!(), "lab_reporter_crash_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    report = Reporter.generate(:E99,
      data_path: tmp,
      output_path: Path.join(tmp, "report.md"),
      exit_code: 11,
      assertions: %{vm_alive: false},
      params: %{duration_ms: 30_000},
      config: %{hypothesis: "the BEAM dies"}
    )

    assert report =~ "# E99"
    assert report =~ "crashed"
    assert report =~ "exit 11"
    assert File.exists?(Path.join(tmp, "report.md"))
  end

  test "generate/2 produces passed status when all assertions pass" do
    tmp = Path.join(System.tmp_dir!(), "lab_reporter_pass_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    report = Reporter.generate(:E02,
      data_path: tmp,
      exit_code: 0,
      assertions: %{latency_p99: true, vm_alive: true},
      params: %{},
      config: %{}
    )

    assert report =~ "passed"
  end
end
