%{
  id: :E20,
  slug: "oban_interaction",
  mode: :in_process,
  tags: [:slow, :oban],
  nif: {Lab.Native, :cpu_work_ms_dirty, 1},
  params: %{
    job_count: %{default: 100, min: 10, max: 500, label: "Total Oban jobs"},
    concurrency: %{default: 10, min: 1, max: 50, label: "Oban worker concurrency"},
    duration_ms: %{default: 5_000, min: 1_000, max: 30_000, label: "Per-job NIF duration (ms)"}
  },
  thresholds: %{
    vm_alive: true,
    run_queue_max: 10
  },
  time_budget_ms: 600_000,
  hypothesis: "DirtyCpu NIF jobs via Oban complete without heartbeat failures or scheduler starvation."
}
