defmodule Lab.NativeTest do
  use ExUnit.Case, async: true

  @moduletag :native

  test "hello/0 returns :ok atom" do
    assert Lab.Native.hello() == :ok
  end

  test "cpu_work_ms/1 returns an integer after CPU work" do
    result = Lab.Native.cpu_work_ms(10)
    assert is_integer(result)
    assert result > 0
  end

  test "cpu_work_ms_dirty/1 returns an integer after dirty CPU work" do
    result = Lab.Native.cpu_work_ms_dirty(10)
    assert is_integer(result)
    assert result > 0
  end

  test "cpu_work_ms/1 approximately respects the duration" do
    start = System.monotonic_time(:millisecond)
    Lab.Native.cpu_work_ms(50)
    elapsed = System.monotonic_time(:millisecond) - start
    # Allow some tolerance — the busy loop checks elapsed time periodically
    assert elapsed >= 45
    assert elapsed < 200
  end
end
