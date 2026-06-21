%{
  id: :E18,
  slug: "large_binary",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :large_binary_mb, 1},
  params: %{
    mb: %{default: 100, min: 10, max: 1_024, label: "Binary size (MiB)"}
  },
  thresholds: %{
    vm_alive: true,
    rss_max_mb: 3_000
  },
  time_budget_ms: 120_000,
  hypothesis: "Large NIF binary transfer cost grows linearly with size; GC recovers the allocation."
}
