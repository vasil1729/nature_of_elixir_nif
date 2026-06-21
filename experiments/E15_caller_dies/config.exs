%{
  id: :E15,
  slug: "caller_dies",
  mode: :in_process,
  tags: [:slow],
  workload: fn params ->
    duration_ms = Map.get(params, :duration_ms, 5_000)
    kill_after_ms = Map.get(params, :kill_after_ms, 100)
    caller = spawn(fn -> Lab.Native.cpu_work_ms(duration_ms) end)
    Process.sleep(kill_after_ms)
    Process.exit(caller, :kill)
    Process.sleep(duration_ms + 500)
    {0, :completed}
  end,
  params: %{
    duration_ms: %{default: 5_000, min: 1_000, max: 30_000, label: "NIF duration (ms)"},
    kill_after_ms: %{default: 100, min: 10, max: 1_000, label: "Kill caller after (ms)"}
  },
  thresholds: %{
    vm_alive: true
  },
  time_budget_ms: 120_000,
  hypothesis: "Killing the caller process does not interrupt a running NIF -- the NIF completes."
}
