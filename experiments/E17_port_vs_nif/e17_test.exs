defmodule E17Test do
  use Lab.ExperimentCase, experiment: :E17
  @moduletag :slow

  test "E17: port crash is isolated -- calling BEAM process survives", ctx do
    {:ok, result} = run_experiment(ctx, params: %{duration_ms: 500})
    assert_all_passed(result)
  end
end
