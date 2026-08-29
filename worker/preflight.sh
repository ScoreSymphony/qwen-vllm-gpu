#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${QWEN_WORKER_ENV:-$SCRIPT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
TARGET_DIR="${TARGET_DIR:-$HOME/scoresymphony-workspace/scoresymphony-infrastructure}"
OPENAI_API_KEY="${OPENAI_API_KEY:-local-vllm}"
OPENAI_BASE_URL="${OPENAI_BASE_URL:-http://127.0.0.1:8000/v1}"
OPENAI_MODEL="${OPENAI_MODEL:-Qwen3-Coder-Next-FP8}"
VLLM_READY_TIMEOUT_SECONDS="${VLLM_READY_TIMEOUT_SECONDS:-3600}"

for cmd in curl git qwen nvidia-smi docker; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "PRECHECK FAIL: missing command: $cmd" >&2
    exit 1
  }
done

[[ -d "$TARGET_DIR/.git" ]] || {
  echo "PRECHECK FAIL: target repository not found: $TARGET_DIR" >&2
  exit 1
}
[[ -f "$TARGET_DIR/TASKS/README.md" ]] || {
  echo "PRECHECK FAIL: TASKS/README.md missing" >&2
  exit 1
}

for n in 001 002 003 004 005 006 007; do
  find "$TARGET_DIR/TASKS" -maxdepth 1 -type f -name "TASK-${n}_*.md" -print -quit | grep -q . || {
    echo "PRECHECK FAIL: TASK-${n} missing" >&2
    exit 1
  }
done

if [[ -n "$(git -C "$TARGET_DIR" status --porcelain)" ]]; then
  echo "PRECHECK FAIL: target repository is not clean before the pilot" >&2
  git -C "$TARGET_DIR" status --short >&2
  exit 1
fi

current_branch="$(git -C "$TARGET_DIR" branch --show-current)"
[[ "$current_branch" == "$TARGET_BRANCH" ]] || {
  echo "PRECHECK FAIL: expected branch $TARGET_BRANCH, got $current_branch" >&2
  exit 1
}

health_url="${OPENAI_BASE_URL%/v1}/health"
printf 'Waiting for vLLM health endpoint: %s (timeout=%ss)\n' "$health_url" "$VLLM_READY_TIMEOUT_SECONDS"
start_epoch="$(date +%s)"
while true; do
  if curl -fsS --max-time 5 "$health_url" >/dev/null 2>&1; then
    break
  fi
  now_epoch="$(date +%s)"
  if (( now_epoch - start_epoch >= VLLM_READY_TIMEOUT_SECONDS )); then
    echo "PRECHECK FAIL: vLLM health endpoint did not become ready within ${VLLM_READY_TIMEOUT_SECONDS}s" >&2
    exit 1
  fi
  sleep 5
done

models_json="$(curl -fsS --max-time 20 \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  "$OPENAI_BASE_URL/models")"
printf '%s' "$models_json" | grep -Fq "$OPENAI_MODEL" || {
  echo "PRECHECK FAIL: expected model not returned by /v1/models" >&2
  printf '%s\n' "$models_json" >&2
  exit 1
}

payload=$(printf '{"model":"%s","messages":[{"role":"user","content":"Reply with exactly READY"}],"temperature":0,"max_tokens":8}' "$OPENAI_MODEL")
chat_json="$(curl -fsS --max-time 120 \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d "$payload" \
  "$OPENAI_BASE_URL/chat/completions")"
printf '%s' "$chat_json" | grep -Fq '"choices"' || {
  echo "PRECHECK FAIL: chat completion did not return choices" >&2
  printf '%s\n' "$chat_json" >&2
  exit 1
}

printf '\n=== GPU WORKER PREFLIGHT: PASS ===\n'
printf 'gpu='; nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader | head -n 1
printf 'qwen=%s\n' "$(qwen --version 2>/dev/null || echo unknown)"
printf 'repo=%s\n' "$TARGET_DIR"
printf 'branch=%s\n' "$current_branch"
printf 'head=%s\n' "$(git -C "$TARGET_DIR" rev-parse HEAD)"
printf 'api=%s\n' "$OPENAI_BASE_URL"
printf 'model=%s\n' "$OPENAI_MODEL"
