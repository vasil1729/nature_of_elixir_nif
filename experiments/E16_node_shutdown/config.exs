%{
  id: :E16,
  slug: "node_shutdown",
  mode: :isolated,
  tags: [:crash, :slow],
  nif: {Lab.Native, :cpu_work_ms, 1},
  params: %{
    duration_ms: %{default: 30_000, min: 5_000, max: 120_000, label: "NIF duration (ms)"},
    shutdown_after_ms: %{default: 1_000, min: 100, max: 5_000, label: "Shutdown after (ms)"}
  },
  thresholds: %{
    vm_crashed: true
  },
  time_budget_ms: 60_000,
  hypothesis: "Node shutdown during a long NIF eventually terminates the isolated BEAM."
}
