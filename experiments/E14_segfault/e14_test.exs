defmodule E14Test do
  use Lab.ExperimentCase, experiment: :E14
  @moduletag :crash

  test "E14: NIF segfault kills isolated child BEAM -- parent survives", ctx do
    {:ok, result} = run_experiment(ctx)
    assert_crashed(result)
  end
end
