%{
  id: :E17,
  slug: "port_vs_nif",
  mode: :in_process,
  tags: [:slow],
  port_cmd: "cpu_work",
  params: %{
    duration_ms: %{default: 1_000, min: 100, max: 10_000, label: "CPU work duration (ms)"}
  },
  thresholds: %{
    vm_alive: true
  },
  time_budget_ms: 120_000,
  hypothesis: "Port crash is isolated to the port process; the BEAM VM survives (unlike a NIF crash)."
}
