#!/bin/bash
# scripts/run_experiment.sh
# Runs a single experiment headless (in Docker or locally).
#
# Usage:
#   scripts/run_experiment.sh E02
#   scripts/run_experiment.sh E02 --params duration_ms=60000
#   scripts/run_experiment.sh E02 --local
#   scripts/run_experiment.sh E02 --compare   (diff against golden baseline)
#
# Exit codes:
#   0 — all assertions passed
#   1 — one or more assertions failed
#   2 — experiment crashed (BEAM died)
#   3 — infrastructure error (container not running, etc.)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse args
EXP_ID=""
LOCAL=false
COMPARE=false
PARAMS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)  LOCAL=true; shift ;;
    --compare) COMPARE=true; shift ;;
    --params) shift; while [[ $# -gt 0 && "$1" != --* ]]; do PARAMS+=("$1"); shift; done ;;
    -p)       shift; while [[ $# -gt 0 && "$1" != --* ]]; do PARAMS+=("$1"); shift; done ;;
    *)        EXP_ID="$1"; shift ;;
  esac
done

if [[ -z "$EXP_ID" ]]; then
  echo "Usage: scripts/run_experiment.sh E## [--params key=value ...] [--local] [--compare]"
  echo ""
  echo "Available experiments:"
  if $LOCAL; then
    cd "$ROOT_DIR/umbrella" && mix run -e 'IO.inspect(Lab.ExperimentConfig.list_ids())' 2>/dev/null || echo "  (run from umbrella to list)"
  else
    docker compose -f "$ROOT_DIR/docker/docker-compose.yml" exec -T lab mix run -e 'IO.inspect(Lab.ExperimentConfig.list_ids())' 2>/dev/null || echo "  (start container first)"
  fi
  exit 3
fi

PARAM_ARGS=""
for p in "${PARAMS[@]}"; do
  PARAM_ARGS="$PARAM_ARGS --params $p"
done

if $LOCAL; then
  # Local execution — uses host Elixir/Rust
  echo "[run_experiment] Running $EXP_ID locally..."
  cd "$ROOT_DIR/umbrella"
  elixir -e "Lab.Runner.CLI.main([\"$EXP_ID\"$PARAM_ARGS])"
else
  # Docker execution — runs inside the lab container
  if ! docker compose -f "$ROOT_DIR/docker/docker-compose.yml" ps lab | grep -q "Up"; then
    echo "[run_experiment] Container not running. Starting..."
    docker compose -f "$ROOT_DIR/docker/docker-compose.yml" up -d
    sleep 5
  fi

  echo "[run_experiment] Running $EXP_ID in Docker..."
  docker compose -f "$ROOT_DIR/docker/docker-compose.yml" exec -T lab \
    elixir -e "Lab.Runner.CLI.main([\"$EXP_ID\"$PARAM_ARGS])"
fi

EXIT_CODE=$?

if $COMPARE; then
  BASELINE="$ROOT_DIR/experiments/${EXP_ID}_*/baselines/metrics.jsonl"
  CURRENT="$ROOT_DIR/data/$(echo $EXP_ID | tr '[:upper:]' '[:lower:]')/metrics.jsonl"
  echo "[run_experiment] Comparing against golden baseline..."
  if ls $BASELINE 1>/dev/null 2>&1; then
    echo "  Baseline: $BASELINE"
    echo "  Current:  $CURRENT"
    # Detailed comparison will be added in commit 16 (harness hardening)
    echo "  (baseline comparison — full implementation in Phase 2)"
  else
    echo "  No baseline found at $BASELINE"
  fi
fi

exit $EXIT_CODE
