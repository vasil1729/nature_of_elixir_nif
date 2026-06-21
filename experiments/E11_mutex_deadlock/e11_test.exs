defmodule E11Test do
  use Lab.ExperimentCase, experiment: :E11
  @moduletag [:slow, :crash]

  test "E11: mutex deadlock hangs the VM -- watchdog kills it", ctx do
    {:ok, result} = run_experiment(ctx)
    assert_crashed(result)
  end
end
