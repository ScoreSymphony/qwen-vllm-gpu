#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${QWEN_WORKER_ENV:-$SCRIPT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
export RUN_ID
MONITOR_OUTPUT_DIR="${MONITOR_OUTPUT_DIR:-$ROOT_DIR/monitoring/logs}"
mkdir -p "$MONITOR_OUTPUT_DIR/$RUN_ID"

monitor_pid=''
cleanup() {
  status=$?
  trap - INT TERM EXIT
  if [[ -n "$monitor_pid" ]] && kill -0 "$monitor_pid" 2>/dev/null; then
    kill -TERM "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true
  fi
  printf '\nPilot run: %s\n' "$RUN_ID"
  printf 'Monitoring: %s/%s\n' "$MONITOR_OUTPUT_DIR" "$RUN_ID"
  printf 'Qwen logs: %s/logs/%s\n' "$SCRIPT_DIR" "$RUN_ID"
  exit "$status"
}
trap cleanup INT TERM EXIT

echo "=== START MONITORING ==="
RUN_ID="$RUN_ID" MONITOR_OUTPUT_DIR="$MONITOR_OUTPUT_DIR" \
  bash "$ROOT_DIR/monitoring/run-monitoring.sh" \
  > "$MONITOR_OUTPUT_DIR/$RUN_ID/monitor-controller.log" 2>&1 &
monitor_pid=$!

sleep 2

echo "=== BOOTSTRAP WORKER ==="
bash "$SCRIPT_DIR/bootstrap.sh"

echo
echo "=== PREFLIGHT ==="
bash "$SCRIPT_DIR/preflight.sh"

echo
echo "=== RUN TASK CHAIN ==="
set +e
RUN_ID="$RUN_ID" bash "$SCRIPT_DIR/run-task-chain.sh"
qwen_status=$?
set -e

echo
echo "=== TASK CHAIN FINISHED: exit=$qwen_status ==="
exit "$qwen_status"
