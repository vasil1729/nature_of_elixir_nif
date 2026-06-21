%{
  id: :E07,
  slug: "filesystem_stall",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :fs_read_bytes_dirty_io, 1},
  params: %{
    mb: %{default: 256, min: 1, max: 512, label: "Read size (MB)"}
  },
  thresholds: %{
    vm_alive: true,
    run_queue_max: 2
  },
  time_budget_ms: 120_000,
  hypothesis: "DirtyIo filesystem-stall NIF keeps normal schedulers free."
}
