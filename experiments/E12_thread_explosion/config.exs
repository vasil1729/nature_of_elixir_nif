%{
  id: :E12,
  slug: "thread_explosion",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :spawn_threads, 1},
  params: %{
    count: %{default: 100, min: 10, max: 1_000, label: "Thread count"}
  },
  thresholds: %{
    vm_alive: true,
    rss_max_mb: 3_000
  },
  time_budget_ms: 120_000,
  hypothesis: "Spawning N OS threads from a NIF grows RSS by N*8MiB and thread count proportionally."
}
