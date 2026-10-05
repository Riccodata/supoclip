#!/usr/bin/env bash
# Starts the SupoClip API and arq worker side by side in one Railway service.
set -euo pipefail
cd /app

# Everything that must survive redeploys lives on the Railway volume.
DATA_DIR="${RAILWAY_VOLUME_MOUNT_PATH:-/data}"
mkdir -p "$DATA_DIR/work" "$DATA_DIR/cache" "$DATA_DIR/user-fonts"
export TEMP_DIR="${TEMP_DIR:-$DATA_DIR/work}"
# Whisper downloads its model weights under XDG_CACHE_HOME.
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$DATA_DIR/cache}"

# User-uploaded caption fonts are stored inside the image's fonts directory.
if [ ! -L /app/fonts/users ]; then
  rm -rf /app/fonts/users
  ln -s "$DATA_DIR/user-fonts" /app/fonts/users
fi

.venv/bin/python /app/railway/bootstrap_db.py

# WORKER_MODE=on-demand (default) runs the arq worker only while jobs are
# queued: `arq --burst` exits once the queue is empty, so the GBs held by the
# video libraries go back to the OS between jobs instead of being billed around
# the clock. A job waits a few seconds longer while the worker starts.
# WORKER_MODE=always keeps a permanent worker, as docker-compose does.
run_worker_on_demand() {
  export REDISCLI_AUTH="${REDIS_PASSWORD:-}"
  while true; do
    queued=$(redis-cli -h "$REDIS_HOST" -p "${REDIS_PORT:-6379}" --no-auth-warning \
      ZCARD supoclip_tasks 2>/dev/null || true)
    if [[ "$queued" =~ ^[0-9]+$ ]] && [ "$queued" -gt 0 ]; then
      .venv/bin/arq --burst src.workers.tasks.WorkerSettings || sleep 5
    else
      sleep 3
    fi
  done
}

if [ "${WORKER_MODE:-on-demand}" = "always" ]; then
  .venv/bin/arq src.workers.tasks.WorkerSettings &
else
  run_worker_on_demand &
fi
# Railway's healthchecks and edge connect over IPv4. uvicorn's "::" would be
# IPv6-only, because asyncio disables dual-stack on IPv6 listening sockets.
.venv/bin/uvicorn src.main:app --host 0.0.0.0 --port "${PORT:-8000}" &

trap 'kill -TERM $(jobs -p) 2>/dev/null' TERM INT

# If either process exits, stop the container so Railway restarts both.
set +e
wait -n
status=$?
kill -TERM $(jobs -p) 2>/dev/null
exit "$status"
