# 13 — Runbook

> Build, run, debug, and troubleshoot the lab.

## Build

### First-time build (Docker)

```bash
docker compose -f docker/docker-compose.yml build
# → multi-stage: cargo build (Rust) then mix compile (Elixir)
# ~5–10 minutes depending on network and host
```

### First-time build (local)

Requires: Elixir 1.18.4, OTP 28, Rust 1.92 (see `.tool-versions`).

```bash
cd umbrella
mix deps.get
mix compile
cd apps/lab_native/native && cargo build --release && cd -
cd apps/lab_port/native && cargo build --release && cd -
```

### Rebuild after Rust changes

```bash
# Docker
docker compose -f docker/docker-compose.yml exec lab bash -c \
  "cd umbrella/apps/lab_native/native && cargo build --release"

# Local
cd umbrella/apps/lab_native/native && cargo build --release
```

### Rebuild after Elixir changes

```bash
# Docker
docker compose -f docker/docker-compose.yml exec lab mix compile

# Local
cd umbrella && mix compile
```

## Run

### Start the control room (primary)

```bash
docker compose -f docker/docker-compose.yml up
# → Phoenix LiveView at http://localhost:4000
```

### Run an experiment headless

```bash
# Inside the container
docker compose -f docker/docker-compose.yml exec lab \
  scripts/run_experiment.sh E02

# From host, against the running container
docker compose -f docker/docker-compose.yml exec lab \
  scripts/run_experiment.sh E02

# Local (no Docker)
scripts/run_experiment.sh E02 --local
```

### Run the full characterization suite

```bash
docker compose -f docker/docker-compose.yml exec lab \
  mix test --only slow
```

### Run only crash experiments

```bash
docker compose -f docker/docker-compose.yml exec lab \
  mix test --only crash
```

⚠️ **Don't run `--only crash` outside Docker.** E14 will segfault your
shell's BEAM.

## Run an experiment in the UI

1. Open http://localhost:4000
2. Click "Catalog"
3. Find the experiment (e.g. E02)
4. Click "Run"
5. Adjust parameters if desired (defaults from `config.exs`)
6. Click "Start" — live charts appear
7. On completion: assertion table + evidence links
8. To compare: go to "History", select two runs, click "Compare"

## Debug

### The NIF didn't load

```
** (UndefinedFunctionError) function Lab.Native.cpu_work_ms/1 is undefined
```

Causes:
- The `.so` wasn't built: `cargo build` in `lab_native/native/`
- The `.so` isn't on the path `lab_native` expects: check
  `lib/lab_native.ex`'s `load_nif!` call
- Architecture mismatch (e.g. built for glibc, running on musl): use the
  Docker image

### The port binary won't start

```
** (SystemLimitError) no port binary at priv/native/lab_port
```

Causes:
- `cargo build` in `lab_port/native/` didn't run
- The binary isn't copied to `priv/native/`: check `mix.exs`'s aliases

### The UI froze during E01

This is **correct behavior**. E01's 30s normal NIF blocks a scheduler; the
LiveView process may be on that scheduler. Wait 30 seconds — the dashboard
resumes and shows a banner explaining the freeze was the experiment.

If it doesn't resume after 60s, the Watchdog should have killed the
experiment. Check `data/E01/watchdog.jsonl` for events.

### A crash experiment killed the container

If E14 was accidentally run in-process (mode misconfigured):

```bash
docker compose -f docker/docker-compose.yml restart lab
```

Postgres data persists (named volume). `data/E##/*.jsonl` may be lost
(container filesystem reset) — that's why Postgres mirrors them.

### `mix test --only oban` fails with connection error

Postgres isn't up:

```bash
docker compose -f docker/docker-compose.yml up -d postgres
# wait a few seconds, then retry
```

Check `docker/docker-compose.yml`'s `postgres` service for the port and
credentials, and `umbrella/config/dev.exs` for the DB URL.

### pdfium link error (E21)

```
error: linking with cc failed: exit status 1
```

The pdfium binary isn't in the right place. The Dockerfile fetches it; if
you're building locally, download `pdfium-binaries` matching your arch and
put it where `lab_native/native/build.rs` expects. See
[ADR 0007](adr/0007_pdfium_for_pdf_workload.md).

Fallback: switch E21 to `mupdf-rs` (apt `libmupdf-dev`). The ADR records
both paths.

## Troubleshoot

### "My threshold keeps failing"

1. Run the experiment 3×: `scripts/run_experiment.sh E02; scripts/run_experiment.sh E02; scripts/run_experiment.sh E02`
2. Look at the 3 `report.md` files. Is the failing threshold's metric
   stable across runs, or noisy?
3. If stable and consistently failing: the threshold is wrong. Adjust
   `config.exs` with a comment explaining why. See
   [06_reproducibility_protocol.md](06_reproducibility_protocol.md) on
   threshold tuning.
4. If noisy: the threshold is too tight. Widen it with a comment.
5. **Never silently loosen a threshold to make CI green.**

### "The UI shows stale data"

Hard-refresh the browser (Ctrl+Shift+R). LiveView's WebSocket may have
dropped and reconnected without re-fetching. The dashboard's "last update"
timestamp (top right) shows the most recent metric age.

### "Docker build is slow"

The Rust build caches poorly on first run. After the first build,
incremental `cargo build` is fast. If it's still slow, check:
- Are you on ARM but pulling an x86 image? Add `--platform linux/amd64`
  (slower via emulation) or use a native arch image.
- Is the Docker BuildKit cache enabled? `DOCKER_BUILDKIT=1` helps.

### "I want to see what a NIF is actually doing"

Add `:dbg` calls in the Elixir wrapper, or `eprintln!` in the Rust NIF.
For deeper inspection, `gdb` can attach to the BEAM process:

```bash
docker compose -f docker/docker-compose.yml exec lab bash
# find the BEAM pid
pgrep -f beam.smp
# attach
gdb -p <pid>
```

This is rarely needed — the experiments are designed to be observable via
metrics, not a debugger.

## Common failure modes (and what they mean)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| BEAM exits with SIGSEGV (code 11) | E14 segfault ran in-process | Restart container; ensure mode is `:isolated` |
| BEAM exits with 137 | OOM killer | Raise `--memory` in compose; investigate which experiment leaked |
| UI hangs forever | E03 infinite loop in-process | Restart container; ensure mode is `:isolated` |
| `mix test` hangs on E11 | Deadlock in dirty scheduler | The Watchdog should time out; if not, kill the process |
| `:scheduler_wall_time` returns `undefined` | BEAM started without scheduler wall time | Add `+swt` or `+swtdc` if needed (default should be on) |
| Port exits immediately | Bad command JSON | Check the request shape against `lab_port/src/protocol.rs` |

## Clean slate

```bash
# Stop everything
docker compose -f docker/docker-compose.yml down

# Remove all data (Postgres volume + container state)
docker compose -f docker/docker-compose.yml down -v

# Remove all build artifacts
docker compose -f docker/docker-compose.yml down --rmi local
cd umbrella && mix clean --deps && cd -
rm -rf umbrella/apps/lab_native/native/target
rm -rf umbrella/apps/lab_port/native/target
```
