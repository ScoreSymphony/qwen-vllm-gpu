#!/usr/bin/env bash
set -Eeuo pipefail

OUTPUT_FILE="${1:-./system-metrics.csv}"
INTERVAL="${2:-${MONITOR_INTERVAL:-5}}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "timestamp_utc,cpu_util_pct,load1,load5,load15,mem_total_kib,mem_available_kib,mem_used_kib,swap_total_kib,swap_used_kib,root_used_kib,root_available_kib" > "$OUTPUT_FILE"

read_cpu() {
  awk '/^cpu / {
    idle=$5+$6;
    total=0;
    for (i=2; i<=NF; i++) total += $i;
    print total, idle;
    exit
  }' /proc/stat
}

read -r prev_total prev_idle < <(read_cpu)

while true; do
  sleep "$INTERVAL"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  read -r total idle < <(read_cpu)
  delta_total=$((total - prev_total))
  delta_idle=$((idle - prev_idle))

  if (( delta_total > 0 )); then
    cpu_util="$(awk -v total="$delta_total" -v idle="$delta_idle" 'BEGIN { printf "%.2f", 100 * (total-idle) / total }')"
  else
    cpu_util="0.00"
  fi

  prev_total="$total"
  prev_idle="$idle"

  read -r load1 load5 load15 _ < /proc/loadavg

  mem_total="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  mem_available="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
  mem_used=$((mem_total - mem_available))
  swap_total="$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)"
  swap_free="$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)"
  swap_used=$((swap_total - swap_free))

  read -r root_used root_available < <(df -Pk / | awk 'NR==2 {print $3, $4}')

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$timestamp" "$cpu_util" "$load1" "$load5" "$load15" \
    "$mem_total" "$mem_available" "$mem_used" \
    "$swap_total" "$swap_used" "$root_used" "$root_available" \
    >> "$OUTPUT_FILE"
done
