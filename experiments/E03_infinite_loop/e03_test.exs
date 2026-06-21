defmodule E03Test do
  use Lab.ExperimentCase, experiment: :E03
  @moduletag [:slow, :crash]

  test "E03: infinite-loop Normal NIF hangs the VM -- watchdog kills it", ctx do
    {:ok, result} = run_experiment(ctx)
    assert_crashed(result)
  end
end
