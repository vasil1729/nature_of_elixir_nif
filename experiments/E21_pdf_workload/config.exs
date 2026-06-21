%{
  id: :E21,
  slug: "pdf_workload",
  mode: :in_process,
  tags: [:slow, :oban, :pdf],
  nif: {Lab.Native, :pdf_work_dirty, 1},
  params: %{
    render_count: %{default: 1_000, min: 100, max: 5_000, label: "Total renders"},
    concurrency: %{default: 50, min: 1, max: 200, label: "Concurrent renders"},
    render_ms: %{default: 100, min: 10, max: 1_000, label: "Simulated render time (ms)"},
    backend: %{default: "nif", label: "Backend (nif/port)"}
  },
  thresholds: %{
    vm_alive: true,
    run_queue_max: 20
  },
  time_budget_ms: 600_000,
  hypothesis: "1000 concurrent DirtyCpu PDF renders complete without scheduler starvation."
}
