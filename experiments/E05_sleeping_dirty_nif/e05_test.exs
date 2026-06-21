defmodule E05Test do
  use Lab.ExperimentCase, experiment: :E05
  @moduletag :slow

  test "E05: sleeping DirtyIo NIF does not starve normal schedulers", ctx do
    {:ok, result} = run_experiment(ctx, params: %{duration_ms: 3_000})
    assert_all_passed(result)
  end
end
