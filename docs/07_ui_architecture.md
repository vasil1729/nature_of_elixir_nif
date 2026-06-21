# 07 — UI Architecture

> How the Phoenix LiveView control room is structured, and the two execution
> modes that make crash experiments safe to watch.

## Design principles

1. **UI primary, CLI for CI** (ADR 0008). `docker compose up` launches the
   control room at `:4000`. The CLI exists for headless reproduction.
2. **One foundation, two front-ends.** LiveView and the CLI both call
   `lab_core` for instrumentation and `lab_native`/`lab_port` for workloads.
3. **The UI freezing is evidence.** When E01's normal NIF blocks a scheduler,
   the dashboard genuinely stops updating — that *is* the lesson.
4. **Crash experiments isolate.** E03/E08/E11/E14/E16 spawn a child BEAM so
   the UI survives to record the death (ADR 0002).

## Pages

| Route | LiveView | Purpose |
|-------|----------|---------|
| `/` | `DashboardLive` | Real-time BEAM health: per-scheduler utilization bars, run queue, process count, memory, latency p50/p99/max |
| `/catalog` | `CatalogLive` | Browse all 21 experiments: hypothesis, params, tags, status, links to README/report |
| `/catalog/:id/run` | `RunLive` | Parameter form (derived from `config.exs`) → "Run" → live charts during execution → assertions + evidence at completion |
| `/history` | `HistoryLive` | Past runs table (from Postgres); side-by-side comparison overlay (e.g. E01 vs E02 latency) |
| `/reports/:id` | `ReportLive` | Renders `experiments/E##/report.md` in-browser |
| `/reports/final` | `FinalReportLive` | Renders `reports/FINAL_REPORT.md` |
| `/docs` | `DocsLive` | Browses `docs/*.md` in-browser |

## Components (reusable)

| Component | Used by | What it renders |
|-----------|---------|-----------------|
| `SchedulerBar` | Dashboard, Run | Per-scheduler utilization bar (normal vs dirty colored) |
| `MetricCard` | Dashboard, Run | Single metric with label, value, unit, trend |
| `LatencyChart` | Dashboard, Run, History | p50/p99/max over time (chart.js via CDN) |
| `RunChart` | Run, History | Multi-metric overlay during a run |
| `ParamForm` | Run | Inputs/sliders derived from experiment's `config.exs` params schema |
| `AssertionTable` | Run | Pass/fail per threshold after run completes |
| `EvidenceLinks` | Run, Report | Links to `data/E##/*.jsonl`, charts, screenshots |

## Execution modes

### `:in_process` (non-crash experiments)

```
RunLive
  │  Lab.Executor.InProcess.run(exp, params)
  ▼
Task.async (in UI's BEAM)
  │  calls lab_native / lab_port
  │
  ├─ lab_core.Sampler ──broadcast──► Phoenix.PubSub ──► LiveView
  ├─ lab_core.LatencyProbe ──broadcast──► ...
  └─ lab_core.SystemProbe ──broadcast──► ...
```

The workload runs in the UI's BEAM. Telemetry broadcasts via PubSub to all
subscribed LiveView processes. The dashboard updates in real time.

**During E01 (30s normal NIF):** the scheduler running the NIF is stuck in
C. PubSub broadcasts from *other* schedulers still work, but the LiveView
process itself may be on the blocked scheduler — so the dashboard genuinely
freezes for the NIF's duration. The UI shows a banner on resume:
"Scheduler was blocked for 30.0s. That freeze was the experiment."

### `:isolated` (crash experiments)

```
RunLive
  │  Lab.Executor.Isolated.run(exp, params)
  ▼
System.cmd("docker", ["exec", "lab", "elixir", "+S", "4:4", ...,
                       "-e", "Lab.IsolatedRunner.run(:E14, params)"])
  │
  ├─ stdout: JSONL metrics stream ──► parse ──► PubSub ──► LiveView
  └─ exit:  {0, 11, 137, ...} ──► record as evidence
```

A fresh BEAM runs the experiment. The UI stays alive and streams the child's
metrics. On death (E14 segfault → exit 11), the UI records:

> "Child BEAM exited with code 11 (SIGSEGV) at T+2.3s. Evidence recorded."

The child BEAM gets the same flags (`+S 4:4 +SDcpu 4:4 +SDio 4:4 +A 10`) for
reproducibility with the in-process experiments.

## Telemetry pipeline

```
lab_core.Sampler ─┐
lab_core.LatencyProbe ─┤── :telemetry.execute(:lab, ..., metrics)
lab_core.SystemProbe ─┘                │
                                       ▼
                          Lab.TelemetryPub (handler)
                                       │
                          ┌────────────┴────────────┐
                          ▼                         ▼
                  Phoenix.PubSub            Postgres (history)
                  topic "lab:metrics"       table: runs, metrics
                          │
                          ▼
                  LiveView processes
                  (DashboardLive, RunLive)
```

`:telemetry` is the canonical bus. `Lab.TelemetryPub` fans out to PubSub
(for live UI) and Postgres (for history/comparison). The CLI path skips
PubSub but still writes Postgres + JSONL.

## Postgres schema (for history)

```sql
CREATE TABLE runs (
  id          BIGSERIAL PRIMARY KEY,
  experiment  TEXT NOT NULL,         -- "E02"
  params      JSONB NOT NULL,
  started_at  TIMESTAMPTZ NOT NULL,
  ended_at    TIMESTAMPTZ,
  exit_code   INT,
  status      TEXT,                  -- "pass" | "fail" | "crashed"
  assertions  JSONB                  -- per-threshold pass/fail
);

CREATE TABLE metrics (
  run_id      BIGINT NOT NULL REFERENCES runs(id),
  ts          BIGINT NOT NULL,       -- monotonic ms
  kind        TEXT NOT NULL,         -- "sampler" | "latency" | "system"
  data        JSONB NOT NULL
);

CREATE INDEX ON metrics (run_id, ts);
```

The UI's History page queries these for run comparison. JSONL files are the
authoritative source; Postgres is a queryable mirror.

## Real-time update mechanism

LiveView processes subscribe to `Phoenix.PubSub.subscribe("lab:metrics")` in
`handle_mount`. `handle_info/2` receives metric events and re-renders via
`send_update/3` to chart components.

We use **chart.js** (via CDN, no npm build) for the chart components. The
LiveView pushes new data points to a `<canvas>` via a small `phx-hook` that
calls `chart.update()`. This keeps the build chain simple (no webpack/esbuild).

## What the UI does NOT do

- It is not a production monitoring tool. No alerting, no auth, no SSL.
- It does not persist user accounts. It's a lab instrument.
- It does not try to be Grafana. Cross-run comparison is enough; time-series
  databases are out of scope (we dropped Prometheus+Grafana — ADR 0003).
- It does not render during a scheduler block on purpose. The freeze is
  the evidence.
