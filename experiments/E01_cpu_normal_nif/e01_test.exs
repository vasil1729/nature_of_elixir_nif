defmodule E01Test do
  use Lab.ExperimentCase, experiment: :E01
  @moduletag :slow

  test "E01: normal NIF blocks scheduler -- run queue backs up", ctx do
    {:ok, result} = run_experiment(ctx, params: %{duration_ms: 5_000, concurrency: 4})
    assert_all_passed(result)
  end
end
