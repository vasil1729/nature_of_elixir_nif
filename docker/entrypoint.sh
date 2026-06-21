#!/bin/sh
# docker/entrypoint.sh
# Runs migrations (for Oban/Ecto) then starts Phoenix (or mix test).
# Scheduler flags come from $ERL_FLAGS (set in Dockerfile).

set -e

cd /app/umbrella

# Ensure DATABASE_URL is set for migrations
: "${DATABASE_URL:?DATABASE_URL is required}"

echo "[entrypoint] Running migrations..."
mix ecto.migrate || {
  echo "[entrypoint] migrations failed (database may not be ready yet); retrying once in 5s"
  sleep 5
  mix ecto.migrate
}

echo "[entrypoint] Migrations complete."

# First arg is the command: default to phx.server
case "$1" in
  phx.server)
    echo "[entrypoint] Starting Phoenix LiveView on :4000 with ERL_FLAGS=$ERL_FLAGS"
    exec mix phx.server
    ;;
  mix)
    shift
    echo "[entrypoint] Running: mix $*"
    exec mix "$@"
    ;;
  scripts/*)
    echo "[entrypoint] Running: $*"
    exec "$@"
    ;;
  *)
    echo "[entrypoint] Running: $*"
    exec "$@"
    ;;
esac
