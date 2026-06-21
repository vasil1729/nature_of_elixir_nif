%{
  id: :E08,
  slug: "rust_panic",
  mode: :isolated,
  tags: [:crash],
  nif: {Lab.Native, :panic_now, 0},
  params: %{},
  thresholds: %{
    vm_alive: true
  },
  time_budget_ms: 30_000,
  hypothesis: "Rustler's catch_unwind converts Rust panics to Erlang errors; the VM survives."
}
