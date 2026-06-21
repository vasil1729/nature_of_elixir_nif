%{
  id: :E19,
  slug: "scheduler_saturation",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :cpu_work_ms, 1},
  params: %{
    concurrency: %{default: 8, min: 1, max: 64, label: "Concurrent NIF calls"},
    duration_ms: %{default: 1_000, min: 100, max: 5_000, label: "Duration per call (ms)"}
  },
  thresholds: %{
    vm_alive: true,
    run_queue_max: 32
  },
  time_budget_ms: 300_000,
  hypothesis: "Normal NIF throughput saturates at scheduler count; dirty NIFs scale linearly without latency impact."
}
