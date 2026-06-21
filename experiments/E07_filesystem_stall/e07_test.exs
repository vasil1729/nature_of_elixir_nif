defmodule E07Test do
  use Lab.ExperimentCase, experiment: :E07
  @moduletag :slow

  test "E07: DirtyIo filesystem-stall NIF -- normal schedulers unaffected", ctx do
    {:ok, result} = run_experiment(ctx, params: %{mb: 32})
    assert_all_passed(result)
  end
end
