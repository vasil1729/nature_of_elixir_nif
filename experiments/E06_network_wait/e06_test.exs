defmodule E06Test do
  use Lab.ExperimentCase, experiment: :E06
  @moduletag :slow

  test "E06: DirtyIo network-wait NIF -- normal schedulers unaffected", ctx do
    {:ok, result} = run_experiment(ctx, params: %{duration_ms: 2_000})
    assert_all_passed(result)
  end
end
