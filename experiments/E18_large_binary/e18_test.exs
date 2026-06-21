defmodule E18Test do
  use Lab.ExperimentCase, experiment: :E18
  @moduletag :slow

  test "E18: large binary transfer -- 100 MiB without OOM", ctx do
    {:ok, result} = run_experiment(ctx, params: %{mb: 100})
    assert_all_passed(result)
  end
end
