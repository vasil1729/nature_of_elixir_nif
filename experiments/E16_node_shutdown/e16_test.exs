defmodule E16Test do
  use Lab.ExperimentCase, experiment: :E16
  @moduletag [:slow, :crash]

  test "E16: node shutdown during NIF -- isolated BEAM terminates", ctx do
    {:ok, result} = run_experiment(ctx, params: %{duration_ms: 5_000, shutdown_after_ms: 500})
    assert_crashed(result)
  end
end
