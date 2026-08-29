#!/usr/bin/env bash
set -Eeuo pipefail

OUTPUT_FILE="${1:-./gpu-metrics.csv}"
INTERVAL="${2:-${MONITOR_INTERVAL:-5}}"

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: nvidia-smi not found; NVIDIA driver/tooling is not available on this host." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "timestamp_utc,index,name,gpu_util_pct,memory_used_mib,memory_total_mib,temperature_c,power_draw_w,power_limit_w,sm_clock_mhz,memory_clock_mhz" > "$OUTPUT_FILE"

while true; do
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  nvidia-smi \
    --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,clocks.current.sm,clocks.current.memory \
    --format=csv,noheader,nounits \
    | while IFS= read -r line; do
        printf '%s,%s\n' "$timestamp" "$line" >> "$OUTPUT_FILE"
      done
  sleep "$INTERVAL"
done
