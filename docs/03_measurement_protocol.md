# 03 — Measurement Protocol

> What we measure, how, units, and tolerances. Every experiment follows this
> protocol so results are comparable. The implementation lives in
> `lab_core`; this doc is the contract.

## Instrumentation components (in `lab_core`)

| Component | Polls | What it records |
|-----------|-------|-----------------|
| `Sampler` | 100ms | scheduler wall time, run queues, process count, reductions, GC |
| `LatencyProbe` | 10ms | round-trip ping to a trivial Elixir process (p50/p99/max) |
| `SystemProbe` | 500ms | RSS, threads, FDs from `/proc/<beam_pid>/status` |
| `Watchdog` | 1s | BEAM liveness check (survives crashes to record them) |
| `Reporter` | once | renders `report.md` from JSONL + assertions |

All components write JSONL to `data/E##/<component>.jsonl` and broadcast to
LiveView via `Phoenix.PubSub` on the `lab:metrics` topic.

## Metrics recorded (full field list)

### Runtime (from `Sampler`)

| Field | Source | Unit |
|-------|--------|------|
| `ts` | `System.monotonic_time(:millisecond)` | ms (monotonic) |
| `scheduler_count` | `:erlang.system_info(:schedulers)` | count |
| `dirty_cpu_count` | `:erlang.system_info(:dirty_cpu_schedulers)` | count |
| `dirty_io_count` | `:erlang.system_info(:dirty_io_schedulers)` | count |
| `online_schedulers` | `:erlang.system_info(:schedulers_online)` | count |
| `sched_util` | diff of `scheduler_wall_time` | list of `{id, util 0..1}` |
| `dirty_cpu_util` | same, dirty CPU ids | list |
| `dirty_io_util` | same, dirty IO ids | list |
| `run_queue` | `:erlang.statistics(:run_queue)` | count |
| `process_count` | `:erlang.system_info(:process_count)` | count |
| `reductions` | `:erlang.statistics(:reductions)` | count (cumulative) |
| `gc_count` | `:erlang.statistics(:garbage_collection)` | count |
| `words_reclaimed` | same | words |
| `beam_total_memory` | `:erlang.memory(:total)` | bytes |
| `beam_process_memory` | `:erlang.memory(:processes)` | bytes |
| `beam_binary_memory` | `:erlang.memory(:binary)` | bytes |
| `beam_ets_memory` | `:erlang.memory(:ets)` | bytes |

### System (from `SystemProbe`)

| Field | Source | Unit |
|-------|--------|------|
| `ts` | monotonic | ms |
| `rss` | `/proc/<pid>/status` → `VmRSS` | KB |
| `threads` | `/proc/<pid>/status` → `Threads` | count |
| `fds` | count of `/proc/<pid>/fd/` | count |
| `cpu_user` | `/proc/<pid>/stat` | jiffies |
| `cpu_system` | same | jiffies |

### Latency (from `LatencyProbe`)

| Field | Source | Unit |
|-------|--------|------|
| `ts` | monotonic | ms |
| `round_trip_us` | send + receive to ping target | microseconds |
| Windowed aggregates (every 1s): `p50_us`, `p99_us`, `max_us`, `count` | | |

### Stability (from `Watchdog` + experiment runner)

| Field | Source | Unit |
|-------|--------|------|
| `vm_alive` | `Node.ping` / OS process check | boolean |
| `vm_degraded` | run queue > threshold for > 1s | boolean |
| `schedulers_blocked` | sched_util[n] == 1.0 for > 1s | boolean |
| `dirty_blocked` | dirty_util[n] == 1.0 for > 1s | boolean |
| `caller_alive` | process liveness | boolean |
| `node_alive` | distributed node check | boolean |

## Sampling math

### Scheduler utilization (windowed)

```elixir
{:scheduler_wall_time, now} = :erlang.statistics(:scheduler_wall_time)
# now: [{sched_id, busy, idle}, ...]
# diff against previous sample, normalize:
util = if busy + idle == 0, do: 0.0, else: busy / (busy + idle)
```

This gives a 0..1 utilization per scheduler per 100ms window. We store both
per-scheduler and aggregates (mean, max).

### Latency percentiles

`LatencyProbe` keeps a sliding window of the last 1000 round-trip samples.
Every 1s it computes p50/p99/max via `:statistics` or a hand-rolled sort.
We don't need a t-digest; 1000 samples is enough for these workloads.

## Tolerances and pinning

To make experiments reproducible across hardware, we pin:

| Variable | Pinned value | How |
|----------|--------------|-----|
| Scheduler count | 4 | `erl +S 4:4` |
| Dirty CPU schedulers | 4 | `erl +SDcpu 4:4` |
| Dirty IO schedulers | 4 | `erl +SDio 4:4` |
| Async threads | 10 | `erl +A 10` |
| Sampler interval | 100ms | `lab_core.Sampler` config |
| Latency probe interval | 10ms | `lab_core.LatencyProbe` config |

**Non-determinism we accept and bound:**
- Exact timings vary with host load → we use **thresholds**, not exact values.
- RSS varies with allocator state → we use **ranges** (min/max across the run).
- Crash timing varies → we record the **first** crash timestamp.

## Threshold format (in each experiment's `config.exs`)

```elixir
thresholds: %{
  latency_p99_max_ms: 50,        # p99 latency must stay below 50ms
  latency_p99_min_ms: 1000,      # for E01: must EXCEED 1000ms (degradation)
  normal_sched_util_max: 30,     # normal sched util must stay below 30%
  dirty_sched_util_min: 90,      # dirty sched util must exceed 90%
  rss_max_mb: 500,               # RSS must stay below 500MB
  rss_growth_min_mb: 100,        # for E09: must grow by at least 100MB
  vm_alive: true,                # BEAM must survive
  vm_alive: false,               # for E14: BEAM must die
  run_queue_max: 100,            # run queue must stay below 100
  process_count_min: 10000       # for E01: 10k processes spawned
}
```

Each threshold is either a `max` (fail if exceeded) or `min` (fail if not
reached). The experiment's test asserts all thresholds after the run.

## Output files (per experiment run)

```
data/E##/
├── sampler.jsonl          # Sampler rows, 100ms cadence
├── latency.jsonl          # LatencyProbe rows, 10ms cadence
├── system.jsonl           # SystemProbe rows, 500ms cadence
├── watchdog.jsonl         # Watchdog events (state transitions)
├── run_meta.json          # experiment id, params, start/end, exit code
└── assertions.json        # threshold check results (pass/fail per threshold)
```

`report.md` is generated from these files by `Reporter`. The UI's History view
reads the same data from Postgres (mirrored for queryability).

## What we deliberately don't measure

- **Per-process memory** for the 10k spawned processes (too noisy; aggregate
  `:erlang.memory(:processes)` is enough).
- **System-wide CPU** beyond the BEAM process (we care about BEAM behavior,
  not host contention).
- **Network throughput** (only E06 involves a socket, and we measure latency
  not bytes).
- **Disk I/O bytes** (only E07 involves a file; we measure stall duration).

If an experiment needs something outside this protocol, it extends the
protocol here first — never invents a one-off metric.
