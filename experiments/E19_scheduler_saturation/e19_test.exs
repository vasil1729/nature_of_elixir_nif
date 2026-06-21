defmodule E19Test do
  use Lab.ExperimentCase, experiment: :E19
  @moduletag :slow

  test "E19: scheduler saturation curve -- VM survives 8 concurrent NIFs", ctx do
    {:ok, result} = run_experiment(ctx, params: %{concurrency: 4, duration_ms: 500})
    assert_all_passed(result)
  end
end
