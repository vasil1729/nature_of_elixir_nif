%{
  id: :E09,
  slug: "memory_leak",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :leak_memory_mb, 1},
  params: %{
    mb: %{default: 100, min: 1, max: 500, label: "MiB leaked per call"},
    iterations: %{default: 5, min: 1, max: 50, label: "Number of calls"}
  },
  thresholds: %{
    vm_alive: true,
    rss_max_mb: 2_000
  },
  time_budget_ms: 120_000,
  hypothesis: "mem::forget leaks grow RSS monotonically; Erlang GC cannot recover native memory."
}
