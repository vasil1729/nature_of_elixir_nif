defmodule E12Test do
  use Lab.ExperimentCase, experiment: :E12
  @moduletag :slow

  test "E12: thread explosion -- VM survives 100 threads", ctx do
    {:ok, result} = run_experiment(ctx, params: %{count: 10})
    assert_all_passed(result)
  end
end
