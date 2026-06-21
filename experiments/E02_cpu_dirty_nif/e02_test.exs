defmodule E02Test do
  use Lab.ExperimentCase, experiment: :E02
  @moduletag :slow

  test "E02: dirty NIF isolates normal schedulers -- low run queue", ctx do
    {:ok, result} = run_experiment(ctx, params: %{duration_ms: 5_000, concurrency: 4})
    assert_all_passed(result)
  end
end
