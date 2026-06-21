#!/bin/bash
# scripts/enter_lab.sh
# Opens an interactive shell in the running lab container.
# Usage: scripts/enter_lab.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

docker compose -f "$ROOT_DIR/docker/docker-compose.yml" exec lab bash || {
  echo "Container not running. Start it with: docker compose -f docker/docker-compose.yml up -d"
  exit 1
}
