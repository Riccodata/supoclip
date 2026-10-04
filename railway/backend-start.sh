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

.venv/bin/arq src.workers.tasks.WorkerSettings &
# "::" listens on IPv6 and IPv4; Railway private networking can be IPv6-only.
.venv/bin/uvicorn src.main:app --host "::" --port "${PORT:-8000}" &

trap 'kill -TERM $(jobs -p) 2>/dev/null' TERM INT

# If either process exits, stop the container so Railway restarts both.
set +e
wait -n
status=$?
kill -TERM $(jobs -p) 2>/dev/null
exit "$status"
