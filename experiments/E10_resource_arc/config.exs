%{
  id: :E10,
  slug: "resource_arc",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :make_resource, 1},
  params: %{
    mb: %{default: 100, min: 1, max: 500, label: "Allocation size (MiB)"},
    iterations: %{default: 10, min: 1, max: 50, label: "Number of allocations"}
  },
  thresholds: %{
    vm_alive: true,
    rss_max_mb: 1_000
  },
  time_budget_ms: 120_000,
  hypothesis: "ResourceArc-backed allocations are freed by the Erlang GC; RSS stays bounded."
}
