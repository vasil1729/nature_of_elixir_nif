defmodule E09Test do
  use Lab.ExperimentCase, experiment: :E09
  @moduletag :slow

  test "E09: native memory leak grows RSS -- GC cannot reclaim", ctx do
    {:ok, result} = Lab.Runner.run_with_config(
      ctx.config,
      params: %{mb: 50, iterations: 3}
    )
    assert result.exit_code == 0
    assert result.assertion_fail == 0
  end
end
