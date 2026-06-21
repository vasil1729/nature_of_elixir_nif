#!/bin/bash
# scripts/build_all.sh
# Builds the Docker image (Rust + Elixir) and compiles all apps.
# Usage: scripts/build_all.sh [--no-cache]

set -e

NO_CACHE=""
if [[ "$1" == "--no-cache" ]]; then
  NO_CACHE="--no-cache"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[build_all] Building Docker image..."
docker compose -f "$ROOT_DIR/docker/docker-compose.yml" build $NO_CACHE

echo "[build_all] Compiling Elixir umbrella..."
docker compose -f "$ROOT_DIR/docker/docker-compose.yml" exec -T lab mix compile 2>/dev/null || true

echo "[build_all] Done. Start with: docker compose -f docker/docker-compose.yml up"
