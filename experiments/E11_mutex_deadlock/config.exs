%{
  id: :E11,
  slug: "mutex_deadlock",
  mode: :isolated,
  tags: [:crash, :slow],
  nif: {Lab.Native, :deadlock, 0},
  params: %{},
  thresholds: %{
    vm_crashed: true
  },
  time_budget_ms: 15_000,
  hypothesis: "Mutex deadlock in a DirtyCpu NIF hangs the child BEAM; Watchdog detects and kills it."
}
