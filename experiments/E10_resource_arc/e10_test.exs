defmodule E10Test do
  use Lab.ExperimentCase, experiment: :E10
  @moduletag :slow

  test "E10: ResourceArc allocations are GC'd -- RSS stays bounded", ctx do
    {:ok, result} = run_experiment(ctx, params: %{mb: 50, iterations: 5})
    assert_all_passed(result)
  end
end
