# 10 — Development Guide

> How to add an experiment, a NIF, a port command, or a UI page. Follow this
> when extending the lab.

## How to add a new experiment

Experiments are numbered E## sequentially. Current: E01–E21. Next: E22.

### 1. Decide the hypothesis

Write one sentence: "I believe X happens under conditions Y." Everything
else follows from that. If you can't state it in one sentence, the
experiment isn't ready.

### 2. Add the NIF (if needed) to `lab_native`

Edit `umbrella/apps/lab_native/native/src/lib.rs`:

```rust
#[nif]
pub fn my_new_thing(arg: u64) -> Result<String, rustler::Error> {
    // implementation
    Ok(format!("did {} things", arg))
}

#[nif(schedule = "DirtyCpu")]
pub fn my_new_thing_dirty(arg: u64) -> Result<String, rustler::Error> {
    // same work, dirty-scheduled
    my_new_thing_impl(arg)
}
```

Register it in the `load!` macro's NIF list. Rebuild with
`mix compile.lab_native` (or `cargo build` in `native/`).

If the experiment needs a port command instead, add it to
`lab_port/src/main.rs`:

```rust
match req.cmd.as_str() {
    "my_new_thing" => { /* ... */ let resp = Response{ id, ok: true, ..}; }
    // ...
}
```

### 3. Create the experiment directory

```
experiments/E##_short_slug/
├── README.md       # from template (below)
├── config.exs      # params schema + thresholds + mode + tags
├── e##_test.exs    # ExUnit test
└── results/        # gitignored
```

### 4. Write `config.exs`

```elixir
%{
  id: :E22,
  slug: "my_new_thing",
  mode: :in_process,              # or :isolated
  tags: [:slow],                  # add :crash, :oban, :pdf as needed
  nif: {:lab_native, :my_new_thing, 1},  # or :port for port-based
  params: %{
    duration_ms: %{default: 30_000, min: 100, max: 60_000, label: "Duration (ms)"},
  },
  thresholds: %{
    latency_p99_max_ms: 50,
    vm_alive: true,
  },
  time_budget_ms: 120_000,        # Watchdog kills the run after this
}
```

### 5. Write `e##_test.exs`

Use the template in `umbrella/apps/lab_runner/lib/lab_runner/test_template.ex`.
Sketch:

```elixir
defmodule E22Test do
  use ExUnit.Case, async: false
  @moduletag :slow

  test "E22: my hypothesis" do
    config = Lab.ExperimentConfig.load!("E22")
    {:ok, results} = Lab.Runner.run(config)
    Lab.Assertions.assert_all(results, config.thresholds)
  end
end
```

### 6. Write `README.md` (template)

```markdown
# E22: My New Thing

**Theme:** X — ...  |  **Mode:** in_process  |  **Tags:** @slow
**Related:** E01, E02

## Hypothesis
[one sentence]

## Background
[What mechanism this probes; cite docs/01 or docs/02 as starting reference]

## Setup
- BEAM flags: +S 4:4 +SDcpu 4:4 +SDio 4:4 +A 10
- NIF: lab_native.my_new_thing/1
- Concurrent load: [if any]
- Sampler: 100ms  |  LatencyProbe: 10ms

## Parameters
| Param | Default | Range | Why |
|-------|---------|-------|-----|

## Execution
- CLI: `scripts/run_experiment.sh E22`
- UI: Catalog → E22 → Run
- Test: `mix test experiments/E22_my_new_thing/`

## Expected Outcome
- [measurable prediction with threshold]

## Actual Outcome
[Filled after first run]

## Evidence
- Metrics: `data/E22/metrics.jsonl`
- Assertions: `results/assertions.txt`

## Conclusion
[Answer hypothesis with numbers; cross-link related experiments]

## References
- [docs/01 or docs/02 link] (starting reference, verified)
- [related experiments]
```

### 7. Run and verify

```bash
scripts/run_experiment.sh E22
# → data/E22/*.jsonl, experiments/E22_*/report.md
mix test experiments/E22_my_new_thing/
# → pass or fail
```

If it fails, investigate. Is the threshold wrong? Is the hypothesis wrong?
Record both in `README.md`'s Actual Outcome and Conclusion.

### 8. Commit

See [11_commit_convention.md](11_commit_convention.md) for the format. One
commit: NIF addition + experiment dir + PLAN.md progress update.

## How to add a NIF to `lab_native`

1. Add the function in `native/src/lib.rs` (or a new module file).
2. For Dirty variants, add a second function with
   `#[nif(schedule = "DirtyCpu")]` or `"DirtyIo"`.
3. Register both in the `rustler::init!` macro's list.
4. Add the Elixir wrapper in `lib/lab_native.ex` if you want a clean API.
5. Rebuild: `cd umbrella/apps/lab_native/native && cargo build` or
   `mix compile.lab_native`.
6. Add a unit test in `test/lab_native_test.exs` for the smoke case.

**Naming convention:** Normal NIFs are `foo_bar/1`; Dirty variants are
`foo_bar_dirty/1` (DirtyCpu) or `foo_bar_dirty_io/1` (DirtyIo). This makes
the scheduling class visible at the call site.

## How to add a port command to `lab_port`

1. Add a `match` arm in `lab_port/src/main.rs`'s command dispatcher.
2. Define the request/response shape in `lab_port/src/protocol.rs`.
3. Add an Elixir wrapper in `lab_port/lib/lab_port.ex`:
   ```elixir
   def my_new_thing(arg) do
     call_port(%{cmd: "my_new_thing", arg: arg})
   end
   ```
4. Rebuild: `cd umbrella/apps/lab_port/native && cargo build`.
5. Test: `Lab.Port.my_new_thing(42)` should return the response.

## How to add a UI page

1. Add the route in `lab_web/lib/lab_web/router.ex`.
2. Create `lib/lab_web/live/my_page_live.ex`:
   ```elixir
   defmodule LabWeb.MyPageLive do
     use LabWeb, :live_view
     def mount(_params, _session, socket), do: {:ok, assign(socket, :foo, nil)}
     def render(assigns), do: ~H"<h1>My Page</h1>"
   end
   ```
3. Add a nav link in `lib/lab_web/components/layout.ex`.
4. If the page needs real-time metrics, subscribe to PubSub in `mount`:
   ```elixir
   if connected?(socket), do: Phoenix.PubSub.subscribe(Lab.PubSub, "lab:metrics")
   ```
5. Handle `handle_info/2` for metric events.
6. For charts, use the `LatencyChart` or `RunChart` component with a
   `phx-hook` pointing at the chart.js canvas.

## Conventions

- **Elixir:** `mix format` everywhere. No `Mix.Config`, use `Config`.
- **Rust:** `cargo fmt` + `cargo clippy` (no warnings). `panic = "unwind"`
  in `Cargo.toml` (required for E08).
- **Commits:** see [11_commit_convention.md](11_commit_convention.md). One
  logical change per commit.
- **Docs:** every new mechanism gets a section in `docs/01` or `docs/02`
  with a link to the experiment that verifies it.
- **No folklore in code comments:** don't write "NIFs are dangerous" in a
  comment. Write *what* the code does and *why*. The experiment README
  carries the hypothesis and conclusion.
- **No premature error handling:** this is a lab. Let things crash. The
  Watchdog catches the crash and records it.

## Testing the harness itself

The harness (`lab_core`, `lab_runner`, `lab_web`) has unit tests that don't
need `@slow`:

```bash
mix test                    # fast tests only (harness)
mix test --only slow        # the characterization suite
```

Fast tests cover:
- Sampler math (utilization calculation correctness)
- Threshold assertion logic
- Config loading and validation
- Reporter output format
- UI component rendering (where feasible)

These are normal TDD-style tests for code we own. The `@slow` experiments
are Jepsen-style characterization tests for code we *don't* own (BEAM).
