%{
  id: :E04,
  slug: "sleeping_normal_nif",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :sleep_for_ms, 1},
  params: %{
    duration_ms: %{default: 60_000, min: 1_000, max: 120_000, label: "Sleep duration (ms)"}
  },
  thresholds: %{
    vm_alive: true,
    run_queue_max: 2
  },
  time_budget_ms: 180_000,
  hypothesis: "A blocking-sleep Normal NIF holds a scheduler thread for its duration, degrading Elixir concurrency."
}
