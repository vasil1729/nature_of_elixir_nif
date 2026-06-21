defmodule E21Test do
  use Lab.ExperimentCase, experiment: :E21
  @moduletag [:slow, :pdf]

  test "E21: 1000 concurrent PDF renders via DirtyCpu NIF -- VM survives", ctx do
    {:ok, result} = run_experiment(ctx, params: %{
      render_count: 10,
      concurrency: 2,
      render_ms: 50,
      backend: "nif"
    })
    assert_all_passed(result)
  end
end
