#!/usr/bin/env bash
set -Eeuo pipefail

OUTPUT_FILE="${1:-./vllm-metrics.log}"
INTERVAL="${2:-${MONITOR_INTERVAL:-5}}"
METRICS_URL="${VLLM_METRICS_URL:-http://127.0.0.1:8000/metrics}"

mkdir -p "$(dirname "$OUTPUT_FILE")"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

while true; do
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '# snapshot %s\n' "$timestamp" >> "$OUTPUT_FILE"

  if curl -fsS --max-time 5 "$METRICS_URL" -o "$tmp_file"; then
    if ! grep -E '^(vllm:|vllm_)' "$tmp_file" >> "$OUTPUT_FILE"; then
      printf '# no vLLM-prefixed metrics found\n' >> "$OUTPUT_FILE"
    fi
  else
    printf '# metrics endpoint unavailable: %s\n' "$METRICS_URL" >> "$OUTPUT_FILE"
  fi

  printf '\n' >> "$OUTPUT_FILE"
  sleep "$INTERVAL"
done
