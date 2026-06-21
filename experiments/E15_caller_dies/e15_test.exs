defmodule E15Test do
  use Lab.ExperimentCase, experiment: :E15
  @moduletag :slow

  test "E15: killing caller mid-NIF does not interrupt the NIF", ctx do
    {:ok, result} = run_experiment(ctx, params: %{duration_ms: 2_000, kill_after_ms: 50})
    assert_all_passed(result)
  end
end
