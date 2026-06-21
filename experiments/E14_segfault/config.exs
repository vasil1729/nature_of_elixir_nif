%{
  id: :E14,
  slug: "segfault",
  mode: :isolated,
  tags: [:crash],
  nif: {Lab.Native, :segfault, 0},
  params: %{},
  thresholds: %{
    vm_crashed: true
  },
  time_budget_ms: 15_000,
  hypothesis: "A NIF segfault kills the entire OS process -- no recovery possible within the BEAM."
}
