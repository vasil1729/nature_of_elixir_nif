# 06 — Reproducibility Protocol

> How anyone can reproduce this lab's results, and how we detect regressions
> across BEAM/Rustler versions.

## The contract

Every experiment is:

1. **An ExUnit test** with strict threshold assertions
2. **Runnable in Docker** with pinned versions
3. **Verified in CI** on GitHub Actions
4. ** producing a `report.md`** with hypothesis, expected, actual, evidence

If you fork this repo and run `mix test --only slow` in Docker, every test
either passes (BEAM behaved as hypothesized) or fails (behavior diverged —
itself a finding).

## Pinned versions

| Component | Version | Pinned where |
|-----------|---------|--------------|
| Elixir | 1.18.4 | `docker/Dockerfile.elixir_rust`, `.tool-versions` |
| Erlang/OTP | 28 | same |
| Rust | 1.92.0 | same, `rust-toolchain.toml` |
| Rustler | 0.38.0 | `lab_native/Cargo.toml` |
| Oban | latest at build | `lab_runner/mix.exs` |
| Postgres | 16 | `docker/docker-compose.yml` |
| pdfium binary | pinned | `docker/Dockerfile.elixir_rust` |

The Dockerfile installs exact versions via `asdf` / `rustup` with
`--disable-toolchain-version-check` where needed. CI re-pins on every run.

## Running an experiment

### Docker (primary)

```bash
docker compose -f docker/docker-compose.yml up -d
scripts/run_experiment.sh E02          # runs inside the lab container
# → data/E02/*.jsonl, experiments/E02_/report.md
```

### Local host (fallback)

```bash
scripts/run_experiment.sh E02 --local  # uses host Elixir/Rust
```

Requires host versions to match the pins. The script checks and warns if
they don't.

### Mix directly (CI)

```bash
mix test experiments/E02_cpu_dirty_nif/e02_test.exs --only slow
# or
mix test --only slow                   # all experiments
mix test --only crash                  # just the crash subset
mix test --only oban                   # just E20/E21 (needs postgres)
```

## Test tags

| Tag | Meaning | Default |
|------|---------|---------|
| `@slow` | Long-running experiment (seconds to minutes) | excluded |
| `@crash` | Expects BEAM death (isolated mode) | excluded |
| `@oban` | Needs Postgres for Oban | excluded |
| `@pdf` | Needs pdfium library | excluded |

`mix test` runs only fast unit tests (the harness itself). `mix test --only
slow` runs the characterization suite. `--only crash` is the dangerous
subset; CI runs it in a separate job with a longer timeout.

## Threshold assertions (ADR 0004)

Each experiment's `config.exs` declares numeric thresholds. The test asserts
each after the run:

```elixir
# In e02_test.exs (sketch)
test "E02: DirtyCpu NIF keeps normal schedulers free", %{config: cfg} do
  {:ok, results} = Lab.Runner.run(cfg)
  assert results.vm_alive,                       "BEAM died"
  assert results.latency.p99 < cfg.latency_p99_max_ms
  assert results.normal_sched_util_max < cfg.normal_sched_util_max
  assert results.dirty_sched_util_min  > cfg.dirty_sched_util_min
end
```

**Strict thresholds** (not "binary only") means: if p99 latency on a 30s
DirtyCpu NIF is 51ms when the threshold is 50ms, the test fails. That's a
signal that something about BEAM's scheduler independence is weaker than
hypothesized — a finding to investigate, not a flaky test to relax.

### Threshold tuning

If a threshold is genuinely wrong (not reflecting a real BEAM property), the
process is:

1. Open an issue citing the experiment and the measured value
2. Run the experiment 3× to confirm the measurement is stable
3. Adjust `config.exs` with a comment explaining the change
4. Re-run; the test should pass consistently
5. Note the adjustment in the experiment's `report.md` under "Methodology"

**Never silently loosen a threshold to make CI green.** That defeats the lab.

## Golden baselines

Each experiment ships a **golden baseline** in `experiments/E##/baselines/`:
the JSONL metrics from a reference run on the pinned versions. The
`--compare` flag diffs a new run against the baseline:

```bash
scripts/run_experiment.sh E02 --compare
# → prints drift report: which metrics moved, by how much
```

This is how we detect regressions across BEAM or Rustler versions. Bump OTP
to 29, re-run, see what changed.

Baselines are committed (small, compressed) so anyone can diff against the
*original* reference, not just their own last run.

## CI workflow (`.github/workflows/lab.yml`)

- **Matrix:** Elixir [1.18.4], OTP [28] (single for now; expand once stable)
- **Services:** `postgres` (for `@oban` experiments)
- **Jobs:**
  1. `build` — build Docker image, compile umbrella, compile Rust
  2. `fast-test` — `mix test` (harness only)
  3. `slow-test` — `mix test --only slow` (non-crash experiments)
  4. `crash-test` — `mix test --only crash` (crash experiments; longer timeout)
  5. `report` — aggregate metrics, upload as artifact
- **Artifacts:** `reports/` + `data/` uploaded for 30 days

CI is the canonical reproduction. If it's green, the lab works. If a
specific experiment fails, the artifact has the evidence.

## What "reproducible" means here

- **Same versions, same inputs → same pass/fail.** Within run-to-run noise,
  thresholds are set with headroom (not at the exact measured value) so
  normal variance doesn't cause flakes.
- **Same versions, different hardware → same pass/fail.** Thresholds are
  expressed in absolute units (ms, %, MB) chosen to hold across reasonable
  hardware. A Raspberry Pi may fail; a modern x86_64 box should pass.
- **Different versions → may differ, and that's the point.** Golden baselines
  let you see *how* behavior changed across versions.

## What reproducibility does NOT promise

- Exact numeric equality across runs (noise is real; thresholds have headroom)
- That the hypothesis is correct (a passing test confirms the hypothesis; a
  failing test is a valid finding)
- That your hardware matches ours (thresholds are conservative; extremes may
  fail)
