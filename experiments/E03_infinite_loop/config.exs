%{
  id: :E03,
  slug: "infinite_loop",
  mode: :isolated,
  tags: [:crash, :slow],
  nif: {Lab.Native, :infinite_loop, 0},
  params: %{
    variant: %{default: "normal", label: "Variant (normal/dirty)"}
  },
  thresholds: %{
    vm_crashed: true
  },
  time_budget_ms: 10_000,
  hypothesis: "An infinite-loop Normal NIF starves all schedulers; Watchdog kills the isolated BEAM."
}
