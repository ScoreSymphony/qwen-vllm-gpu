#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INTERVAL="${MONITOR_INTERVAL:-5}"
OUTPUT_ROOT="${MONITOR_OUTPUT_DIR:-$SCRIPT_DIR/logs}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="$OUTPUT_ROOT/$RUN_ID"
VLLM_CONTAINER="${VLLM_CONTAINER:-scoresymphony-qwen-vllm}"

mkdir -p "$RUN_DIR"

echo "Monitoring run: $RUN_ID"
echo "Output directory: $RUN_DIR"
echo "Interval: ${INTERVAL}s"

auto_metadata="$RUN_DIR/environment.txt"
{
  echo "run_id=$RUN_ID"
  echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "hostname=$(hostname 2>/dev/null || true)"
  echo "kernel=$(uname -srmo 2>/dev/null || true)"
  echo
  echo "=== NVIDIA ==="
  nvidia-smi 2>&1 || true
  echo
  echo "=== Docker ==="
  docker version 2>&1 || true
  echo
  echo "=== Docker Compose ==="
  docker compose version 2>&1 || true
  echo
  echo "=== Memory ==="
  free -h 2>&1 || true
  echo
  echo "=== Filesystem ==="
  df -h / 2>&1 || true
} > "$auto_metadata"

pids=()

cleanup() {
  status=$?
  trap - INT TERM EXIT
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait "${pids[@]:-}" 2>/dev/null || true
  printf 'stopped_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$auto_metadata"
  echo
  echo "Monitoring stopped. Data saved in: $RUN_DIR"
  exit "$status"
}
trap cleanup INT TERM EXIT

"$SCRIPT_DIR/gpu-monitor.sh" "$RUN_DIR/gpu-metrics.csv" "$INTERVAL" &
pids+=("$!")

"$SCRIPT_DIR/system-monitor.sh" "$RUN_DIR/system-metrics.csv" "$INTERVAL" &
pids+=("$!")

"$SCRIPT_DIR/vllm-monitor.sh" "$RUN_DIR/vllm-metrics.log" "$INTERVAL" &
pids+=("$!")

(
  while ! docker inspect "$VLLM_CONTAINER" >/dev/null 2>&1; do
    printf '%s waiting for container %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$VLLM_CONTAINER"
    sleep 2
  done
  docker logs --timestamps --follow "$VLLM_CONTAINER"
) > "$RUN_DIR/vllm-container.log" 2>&1 &
pids+=("$!")

echo "Monitoring active. Press Ctrl+C to stop and preserve the logs."

while true; do
  sleep 3600
done
