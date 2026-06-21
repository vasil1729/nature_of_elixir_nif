defmodule Lab.PortTest do
  use ExUnit.Case, async: true

  @moduletag :port

  test "cpu_work/1 returns {:ok, duration_ms} for a short workload" do
    {:ok, duration_ms} = Lab.Port.cpu_work(50)
    assert is_integer(duration_ms)
    assert duration_ms >= 45
    assert duration_ms < 200
  end

  test "call/2 with unknown command returns error" do
    {:ok, resp} = Lab.Port.call("bogus_cmd")
    refute resp["ok"]
    assert String.contains?(resp["error"], "unknown_command")
  end
end
