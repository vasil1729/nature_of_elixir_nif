%{
  id: :E05,
  slug: "sleeping_dirty_nif",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :sleep_for_ms_dirty_io, 1},
  params: %{
    duration_ms: %{default: 60_000, min: 1_000, max: 120_000, label: "Sleep duration (ms)"}
  },
  thresholds: %{
    vm_alive: true,
    run_queue_max: 1
  },
  time_budget_ms: 180_000,
  hypothesis: "A DirtyIo NIF sleeping 60s leaves normal schedulers free."
}
