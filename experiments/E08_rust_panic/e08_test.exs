defmodule E08Test do
  use Lab.ExperimentCase, experiment: :E08
  @moduletag :crash

  test "E08: Rust panic -- Rustler catches it, VM survives", ctx do
    {:ok, result} = run_experiment(ctx)
    assert result.exit_code == 0,
      "E08: expected isolated BEAM to survive the NIF panic (exit 0), got #{result.exit_code}"
  end
end
