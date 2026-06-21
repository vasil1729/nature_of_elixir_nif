defmodule E04Test do
  use Lab.ExperimentCase, experiment: :E04
  @moduletag :slow

  test "E04: sleeping Normal NIF wastes a scheduler thread", ctx do
    {:ok, result} = run_experiment(ctx, params: %{duration_ms: 3_000})
    assert_all_passed(result)
  end
end
