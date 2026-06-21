%{
  id: :E02,
  slug: "cpu_dirty_nif",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :cpu_work_ms_dirty, 1},
  params: %{
    duration_ms: %{default: 30_000, min: 100, max: 60_000, label: "Duration (ms)"},
    concurrency: %{default: 4, min: 1, max: 32, label: "Concurrent NIF calls"}
  },
  thresholds: %{
    vm_alive: true,
    run_queue_max: 2
  },
  time_budget_ms: 120_000,
  hypothesis: "A DirtyCpu NIF leaves normal schedulers free -- run queue <= 1, latency p99 <= 50ms."
}
