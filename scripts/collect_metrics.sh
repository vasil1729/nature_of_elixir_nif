#!/bin/bash
# scripts/collect_metrics.sh
# Collects and displays metrics from the last run of an experiment.
#
# Usage: scripts/collect_metrics.sh E02
#        scripts/collect_metrics.sh E02 --summary

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

EXP_ID="${1:-}"
SUMMARY=false

if [[ "$2" == "--summary" ]]; then
  SUMMARY=true
fi

if [[ -z "$EXP_ID" ]]; then
  echo "Usage: scripts/collect_metrics.sh E## [--summary]"
  exit 1
fi

DATA_DIR="$ROOT_DIR/data/$(echo "$EXP_ID" | tr '[:upper:]' '[:lower:]')"

if [[ ! -d "$DATA_DIR" ]]; then
  echo "No data directory found for $EXP_ID at $DATA_DIR"
  exit 1
fi

echo "=== Metrics for $EXP_ID ==="
echo "Data directory: $DATA_DIR"
echo ""

for f in sampler.jsonl latency.jsonl system.jsonl watchdog.jsonl; do
  FILE="$DATA_DIR/$f"
  if [[ -f "$FILE" ]]; then
    LINES=$(wc -l < "$FILE")
    echo "  $f: $LINES lines"
  fi
done

if $SUMMARY; then
  echo ""
  echo "=== Summary ==="
  cd "$ROOT_DIR/umbrella"
  elixir -e "
    data_path = \"$DATA_DIR\"
    # Read and summarize metrics
    for f <- [\"sampler.jsonl\", \"latency.jsonl\", \"system.jsonl\", \"watchdog.jsonl\"] do
      path = Path.join(data_path, f)
      if File.exists?(path) do
        rows = File.read!(path) |> String.split(\"\n\", trim: true) |> Enum.map(&Jason.decode!/1, keys: :atoms)
        IO.puts(\"#{f}: #{length(rows)} rows\")
      end
    end
  " 2>/dev/null || echo "  (run from umbrella for detailed summary)"
fi
