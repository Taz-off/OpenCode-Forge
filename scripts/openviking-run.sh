#!/usr/bin/env bash
# openviking-run.sh — start OpenViking (single instance), wait for /health, then run OpenCode.
# No permanent system service: the server lives as long as your session.
# Usage: ./scripts/openviking-run.sh [-- args for opencode]
set -uo pipefail
CONF="$HOME/.openviking/ov.conf"

if curl -sf --max-time 5 http://127.0.0.1:1933/health >/dev/null 2>&1; then
  echo "OpenViking already running."
else
  command -v openviking-server >/dev/null 2>&1 || {
    echo "WARN: openviking-server not found. OpenCode will start with a warning."
    exec opencode "$@" 2>/dev/null || { echo "ERROR: opencode not found either."; exit 1; }
  }
  [ -f "$CONF" ] || { echo "WARN: $CONF missing. Run ./install.sh first."; }
  nohup openviking-server --config "$CONF" >/tmp/openviking.log 2>&1 &
  for _ in $(seq 1 30); do
    sleep 2
    curl -sf --max-time 3 http://127.0.0.1:1933/health >/dev/null 2>&1 && break
  done
  curl -sf --max-time 3 http://127.0.0.1:1933/health >/dev/null 2>&1 \
    || echo "WARN: OpenViking did not answer /health in time. Continuing with a warning."
fi
exec opencode "$@"
