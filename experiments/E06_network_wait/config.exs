%{
  id: :E06,
  slug: "network_wait",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :sleep_for_ms_dirty_io, 1},
  params: %{
    duration_ms: %{default: 5_000, min: 100, max: 30_000, label: "Wait duration (ms)"}
  },
  thresholds: %{
    vm_alive: true,
    run_queue_max: 2
  },
  time_budget_ms: 120_000,
  hypothesis: "DirtyIo-scheduled network-wait NIF keeps scheduler free."
}
