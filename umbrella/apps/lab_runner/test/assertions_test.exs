defmodule Lab.AssertionsTest do
  use ExUnit.Case, async: true

  alias Lab.Assertions

  describe "check_all/2" do
    test "all pass when results meet thresholds" do
      results = %{latency_p99_max_ms: 30, vm_alive: true}
      thresholds = %{latency_p99_max_ms: 50, vm_alive: true}

      {pass, fail, checked} = Assertions.check_all(results, thresholds)

      assert pass == 2
      assert fail == 0
      assert checked == %{latency_p99_max_ms: true, vm_alive: true}
    end

    test "fails when a _max threshold is exceeded" do
      results = %{latency_p99_max_ms: 100}
      thresholds = %{latency_p99_max_ms: 50}

      {pass, fail, checked} = Assertions.check_all(results, thresholds)

      assert pass == 0
      assert fail == 1
      assert checked == %{latency_p99_max_ms: false}
    end

    test "fails when a _min threshold is not reached" do
      results = %{dirty_sched_util_min: 30}
      thresholds = %{dirty_sched_util_min: 90}

      {pass, fail, _checked} = Assertions.check_all(results, thresholds)

      assert pass == 0
      assert fail == 1
    end

    test "passes when a _min threshold is reached" do
      results = %{dirty_sched_util_min: 95}
      thresholds = %{dirty_sched_util_min: 90}

      {pass, fail, _checked} = Assertions.check_all(results, thresholds)

      assert pass == 1
      assert fail == 0
    end

    test "boolean threshold checks exact match" do
      {pass, _, checked} = Assertions.check_all(%{vm_alive: false}, %{vm_alive: false})
      assert pass == 1
      assert checked == %{vm_alive: true}
    end
  end

  describe "all_passed?/1" do
    test "true when fail count is 0" do
      assert Assertions.all_passed?({5, 0, %{}})
    end

    test "false when fail count > 0" do
      refute Assertions.all_passed?({3, 2, %{}})
    end
  end

  describe "extract_results/2" do
    test "converts summary struct to flat results map" do
      summary = %{
        sampler: %{
          rows: 100,
          normal_util_max: 0.25,
          normal_util_mean: 0.10,
          dirty_cpu_util_max: 0.95,
          run_queue_max: 5,
          process_count_max: 10000,
          beam_memory_max: 100_000_000
        },
        latency: %{rows: 1000, windows: 10, p99_max_us: 3100, p50_max_us: 500},
        system: %{rows: 200, rss_max_kb: 204800, rss_max_mb: 200, threads_max: 20},
        watchdog: %{rows: 100, events: [:started], killed: false}
      }

      results = Assertions.extract_results(summary, exit_code: 0)

      assert results.vm_alive == true
      assert results.normal_sched_util_max == 25.0
      assert results.dirty_sched_util_max == 95.0
      assert results.latency_p99_max_ms == 3.1
      assert results.rss_max_mb == 200
      assert results.run_queue_max == 5
    end

    test "vm_alive is false when exit_code != 0" do
      summary = %{
        sampler: %{normal_util_max: nil, normal_util_mean: nil, dirty_cpu_util_max: nil,
                   run_queue_max: 0, process_count_max: 0, beam_memory_max: nil},
        latency: %{p99_max_us: nil, p50_max_us: nil},
        system: %{rss_max_mb: 0, threads_max: 0},
        watchdog: %{events: [], killed: false}
      }

      results = Assertions.extract_results(summary, exit_code: 11)

      assert results.vm_alive == false
      assert results.vm_crashed == true
    end
  end
end
