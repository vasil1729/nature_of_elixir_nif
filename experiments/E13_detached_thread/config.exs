%{
  id: :E13,
  slug: "detached_thread",
  mode: :in_process,
  tags: [:slow],
  nif: {Lab.Native, :detach_thread, 1},
  params: %{
    seconds: %{default: 10, min: 1, max: 60, label: "Thread duration (seconds)"}
  },
  thresholds: %{
    vm_alive: true
  },
  time_budget_ms: 120_000,
  hypothesis: "A detached NIF thread runs and exits silently -- the BEAM is not notified."
}
