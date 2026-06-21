# ADR 0003: LiveView UI over Grafana

## Status

Accepted

## Context

The lab needs visualization of real-time BEAM metrics (scheduler utilization,
latency, run queues, memory) and historical run comparison. Two options:

1. **Prometheus + Grafana** — standard ops stack. `telemetry_metrics_prometheus`
   exports metrics; Grafana renders dashboards. Battle-tested, generic.
2. **Phoenix LiveView UI** — purpose-built control room. `telemetry` →
   PubSub → LiveView → chart.js. Custom-built for this lab.

For a *lab* (not a production system), Grafana's strengths (alerting,
long-term TSDB, multi-source) are mostly irrelevant. Its weaknesses (extra
services, generic dashboards that don't know about experiments, no
experiment-launching UI, no report browsing) are directly relevant.

The lab doesn't just *display* metrics — it *launches experiments*, *tunes
parameters*, *records assertions*, *browses reports*, and *compares runs*.
Grafana does none of that. A LiveView UI does all of it in one place.

## Decision

**Phoenix LiveView is the sole visualization layer.** No Prometheus, no
Grafana services in `docker-compose.yml`.

Run history (for cross-run comparison) is stored in Postgres (already
present for Oban in E20/E21). JSONL files remain the authoritative
per-run record.

## Consequences

**Positive:**
- `docker-compose.yml` drops two services (prometheus + grafana) — simpler
  ops, faster startup, less memory
- One UI does everything: dashboard, catalog, run, history, reports, docs
- The UI knows about experiments (Grafana would need custom annotation
  plumbing to)
- The "UI freezes on E01" lesson works because the dashboard *is* the
  experiment runner — a separate Grafana dashboard wouldn't freeze and
  wouldn't teach the same lesson
- No Grafana dashboard JSON to maintain

**Negative:**
- We build chart components ourselves (SchedulerBar, LatencyChart, RunChart)
  instead of using Grafana's built-in panels — modest upfront cost
- chart.js via CDN is less powerful than Grafana for ad-hoc exploration
- No alerting (the lab doesn't need it; the Watchdog handles liveness)
- Long-term TSDB query is via Postgres, not PromQL — fine for our scale
  (hundreds of runs, not millions of series)

**Neutral:**
- If someone *wants* Grafana later, `telemetry_metrics_prometheus` can be
  added back without architectural change — the `:telemetry` bus is
  already there.

## Revisited

_(none yet)_
