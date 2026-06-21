# 08 — Final Report Rubric

> The final report (`reports/FINAL_REPORT.md`, commit 39) must answer these
> 14 questions. Each answer cites experiment IDs, a passing test, and recorded
> metrics. No answer may rely on documentation or assumptions alone.

## The 14 questions

### 1. What truly blocks a scheduler?

A scheduler is blocked when a NIF running on it doesn't return. The question
is *what kinds* of work do this, with numbers.

**Cite:** E01 (CPU work), E04 (sleep), E06 (network wait), E07 (file stall).
For each: which scheduler utilization hit 100%, for how long, and what the
latency probe showed during the block.

### 2. What only blocks dirty schedulers?

Work scheduled as DirtyCpu or DirtyIo should leave normal schedulers free.
Verify the isolation holds, and quantify any leakage.

**Cite:** E02 (DirtyCpu), E05 (DirtyIo sleep), E19 (saturation). For each:
normal scheduler utilization (should be low), dirty scheduler utilization
(should be high), latency during the run.

### 3. What survives caller death?

If the process that called a NIF dies mid-execution, does the native work
stop? Does memory release? Does the result vanish?

**Cite:** E15. Record: what happens to the NIF call, to the scheduler, to
any allocated memory, to a detached thread (E13 cross-link).

### 4. What survives process death?

If a *different* process dies (not the caller), what happens to ongoing
native work? Compare to caller death.

**Cite:** E17 (Port vs NIF vs Dirty). For the NIF arm: does the NIF notice?
For the Port arm: does the port process survive?

### 5. What survives node shutdown?

`System.stop()` / `init:stop()` during a long NIF. Does the shutdown wait?
Is the NIF interrupted? Does native work continue after the VM is gone
(detached threads)?

**Cite:** E16. Record: graceful vs forced shutdown behavior, timeout,
whether a detached thread (E13) outlives the node.

### 6. What causes scheduler starvation?

A scheduler is starved when its run queue grows unbounded. Quantify the
conditions: NIF duration, concurrency, work type.

**Cite:** E01 (duration sweep), E03 (infinite loop), E19 (concurrency sweep).
For each: run queue growth curve, latency degradation curve.

### 7. What causes dirty scheduler starvation?

Same question for dirty schedulers. When do dirty run queues grow? What's
the latency impact on dirty-scheduled callers vs normal-scheduled callers?

**Cite:** E02 (single long job), E19 (concurrency sweep on dirty). Show the
collapse point: # of jobs > # of dirty schedulers → queue growth.

### 8. What causes memory exhaustion?

Native allocations BEAM can't see (E09), and large term transfers (E18).
Quantify: RSS growth rate, BEAM's reported memory vs RSS, OOM threshold.

**Cite:** E09 (`mem::forget` leak), E18 (binary transfer). Show:
`:erlang.memory(:total)` vs RSS divergence in E09; transfer time curve in
E18.

### 9. What causes VM crashes?

Segfault (E14) kills the VM. Panic (E08) doesn't. What's the full list, and
what's the mechanism for each?

**Cite:** E08 (panic, survives), E14 (segfault, dies). Also note: OOM
(E09/E18 at extreme), `abort` (E14 sub-case).

### 10. What limitations does Rustler solve?

Panic safety (E08), term encoding safety (`Env` lifetime), resource
management (`ResourceArc`). For each: what would happen in raw C, what
Rustler does instead, with the experiment that demonstrates the difference.

**Cite:** E08 (panic caught), E10 (resource GC), and contrast E14 (where
Rustler *can't* help).

### 11. What limitations remain?

Segfault (E14), deadlock (E11), panicked spawned threads (E13), native
memory BEAM can't see (E09). For each: what Rustler doesn't intercept, and
what the experiment showed.

**Cite:** E14, E11, E13, E09. Be specific about the boundary: Rustler's
`catch_unwind` is on the NIF entry path, not inside `unsafe` blocks or
spawned threads.

### 12. When is a Port technically superior?

When crash isolation matters more than call overhead. Quantify: Port call
latency vs NIF call latency (E17), and what survives a port crash vs a NIF
segfault.

**Cite:** E17 (comparison), E14 (segfault — what a Port would have
survived). Include the comparison table from E17.

### 13. When is a Dirty NIF technically superior?

When the work is CPU-bound and you need lower call overhead than a Port,
with normal schedulers protected. Quantify: DirtyCpu vs Port latency and
throughput (E17, E19, E21).

**Cite:** E02 vs E01 (dirty saves normal schedulers), E19 (dirty throughput
curve), E21 (real PDF workload — dirty vs port).

### 14. What practical limits were discovered?

The numbers that inform engineering decisions:
- Max NIF duration before degradation (E01)
- Max dirty scheduler concurrency before queueing (E19)
- Max binary transfer size before OOM (E18)
- Max native threads before OS limits (E12)
- Real-world PDF throughput: NIF vs Dirty vs Port (E21)

**Cite:** E01, E12, E18, E19, E21. Each limit gets a number with conditions.

## Report structure

```markdown
# Final Report — BEAM Characterization Lab

## Methodology
[How experiments were run: pinned versions, Docker, thresholds, CI]

## Findings by Question
[1–14, each with: answer in 1–2 paragraphs + evidence block citing
experiment ID, test result (pass/fail), key metrics, link to report.md]

## Comparison Tables
[E17 NIF vs Dirty vs Port; E01 vs E02 side-by-side; E19 saturation curves]

## Charts
[Embedded from reports/charts/: latency curves, utilization bars, etc.]

## Limitations of this study
[What we didn't test; hardware assumptions; version specificity]

## Reproducing
[One-command: docker compose up + mix test --only slow]
```

## Evidence block format (per answer)

Every answer includes at least one evidence block:

```
> **Evidence:** E02 — test passed.
> - Normal scheduler util (max): 18.4% (threshold: < 30%)
> - Dirty scheduler util (min): 99.2% (threshold: > 90%)
> - Latency p99: 3.1ms (threshold: < 50ms)
> - VM alive: yes
> - Report: experiments/E02_cpu_dirty_nif/report.md
> - Metrics: data/E02/sampler.jsonl (3,000 rows)
```

No answer is accepted without this block. If an experiment hasn't run yet,
the answer is "pending E##" — not a guess.
