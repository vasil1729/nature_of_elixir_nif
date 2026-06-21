# 05 — Safety & Isolation

> What's dangerous in this lab, why we do it anyway, and how Docker + the
> isolated child BEAM contain the blast radius.

## What's dangerous

| Experiment | Danger | Severity |
|------------|--------|----------|
| E03 (infinite loop) | Permanently blocks a scheduler; if run in-process, the UI hangs forever | high |
| E08 (panic) | Process exception; BEAM survives, but the panic path is subtle | low |
| E09 (memory leak) | RSS grows unbounded; can OOM the container | medium |
| E11 (deadlock) | Dirty schedulers wedge; if in-process, the UI hangs | high |
| E14 (segfault) | Kills the entire BEAM with SIGSEGV; no recovery | critical |
| E16 (node shutdown) | BEAM stops; anything in-process dies | high |
| E18 (1GB binary) | Can OOM the container; allocates 1GB | medium |
| E12 (10k threads) | Can hit OS thread limits, exhaust memory | medium |

**The lab deliberately runs all of these.** The danger is the point — but it
must be contained.

## Containment layer 1: Docker

The whole lab runs inside Docker. Every experiment — even in-process ones —
runs inside the `lab` container. If a segfault (E14) or OOM (E09, E18) kills
the BEAM, it kills the container's process, not your host.

Docker settings that matter:

| Setting | Value | Why |
|---------|-------|-----|
| `--memory` | `4g` | Prevents OOM-killer from thrashing the host; container dies first |
| `--memory-swap` | `4g` | No swap fallback; OOM is decisive |
| `--pids-limit` | `8192` | E12 (thread explosion) can't fork-bomb the host |
| `--ulimit nofile` | `4096` | Caps FD leak damage |
| `--cap-drop ALL` | Research lab doesn't need capabilities | Defense in depth |

The `docker-compose.yml` encodes these. See
[09_architecture.md](09_architecture.md) for the full spec.

## Containment layer 2: isolated child BEAM

Crash experiments (E03, E08, E11, E14, E16) run in a **separate BEAM OS
process** spawned by the UI's BEAM via `System.cmd`. See
[ADR 0002](adr/0002_isolated_child_beam_for_crashes.md).

```
UI BEAM (survives)
   │
   ├─ System.cmd("elixir", ["-e", "...", "+S", "4:4", ...])
   │      │
   │      ▼
   │   Child BEAM (may die)
   │      │
   │      └─ stdout: JSONL metrics stream
   │      └─ exit code: 0 (ok) | 11 (SIGSEGV) | 137 (OOM) | ...
   │
   └─ reads stdout → broadcasts to LiveView → records exit as evidence
```

The child BEAM:
- Gets the same `+S/+SDcpu/+SDio` flags (reproducibility)
- Streams JSONL metrics to stdout; UI parses and broadcasts
- On death, the UI records the exit code + last metrics timestamp
- The UI shows: "Child BEAM exited with code 11 (SIGSEGV) at T+2.3s"

This means:
- A segfault in E14 kills the **child**, not the UI
- An infinite loop in E03 wedges the **child**, not the UI
- The UI's dashboard keeps running throughout, recording the failure

## Containment layer 3: in-process with watchdog

Non-crash experiments (E01, E02, E04–E07, E09, E10, E12, E13, E15, E17–E21)
run in the UI's own BEAM. The `Watchdog` component enforces:

- **Time budget:** each experiment declares a max runtime. The Watchdog kills
  the experiment's Task if it exceeds the budget (e.g. E01's 60s cap).
- **Memory guard:** if RSS exceeds a per-experiment ceiling, the Watchdog
  aborts and records an OOM event.
- **Liveness marker:** the experiment writes a heartbeat; if it stops, the
  Watchdog marks the run as "degraded/hung."

**Important:** E01's "UI freezes during the 30s NIF" is **intentional and is
the evidence**, not a bug. The Watchdog records the freeze window. The UI
shows a banner: "Scheduler blocked — dashboard will resume when the NIF
returns."

## What not to do

- **Don't run `mix test --only crash` on your host without Docker.** E14 will
  kill your shell's BEAM (the `elixir` process running Mix). It won't hurt
  your OS, but you'll lose your IEx session.
- **Don't bump `--memory` above host RAM.** The OOM-killer will go after the
  host, not the container.
- **Don't disable the Watchdog time budget to "see what happens."** E03 will
  hang forever. The time budget is there for a reason.
- **Don't run E12 with `--pids-limit` removed.** 10,000 threads can crash
  WSL2.

## Crash experiment protocol (checklist before running)

For E03, E08, E11, E14, E16 — confirm before "Run":

1. ☐ Mode is `isolated` (the UI enforces this; CLI checks too)
2. ☐ Docker container is running (not `--local`)
3. ☐ No other important work in the same container
4. ☐ Time budget is set (default: 120s)
5. ☐ Watchdog is active

The UI greys out "Run" with a warning banner if any check fails.

## Recovery after a crash

If the container's BEAM dies (E14 in-process by mistake, or container OOM):

```bash
docker compose -f docker/docker-compose.yml restart lab
```

The Postgres data (run history) persists across restarts because it's a
named volume. `data/` JSONL files are in-container and lost on restart —
that's why Postgres mirrors them for history.
