defmodule E13Test do
  use Lab.ExperimentCase, experiment: :E13
  @moduletag :slow

  test "E13: detached native thread exits silently -- VM unaware", ctx do
    {:ok, result} = run_experiment(ctx, params: %{seconds: 3})
    assert_all_passed(result)
  end
end
