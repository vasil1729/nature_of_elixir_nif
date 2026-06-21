defmodule E20Test do
  use Lab.ExperimentCase, experiment: :E20
  @moduletag [:slow, :oban]

  test "E20: Oban DirtyCpu jobs -- all complete without heartbeat failure", ctx do
    {:ok, result} = run_experiment(ctx, params: %{job_count: 5, concurrency: 2, duration_ms: 500})
    assert_all_passed(result)
  end
end
