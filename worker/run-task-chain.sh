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
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN in worker/.env or the environment}"

TARGET_DIR="${TARGET_DIR:-$HOME/scoresymphony-workspace/scoresymphony-infrastructure}"
OPENAI_API_KEY="${OPENAI_API_KEY:-local-vllm}"
OPENAI_BASE_URL="${OPENAI_BASE_URL:-http://127.0.0.1:8000/v1}"
OPENAI_MODEL="${OPENAI_MODEL:-Qwen3-Coder-Next-FP8}"
QWEN_MAX_WALL_TIME="${QWEN_MAX_WALL_TIME:-2h}"
QWEN_APPROVAL_MODE="${QWEN_APPROVAL_MODE:-yolo}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
LOG_DIR="${QWEN_LOG_DIR:-$SCRIPT_DIR/logs/$RUN_ID}"
mkdir -p "$LOG_DIR"

ASKPASS="$SCRIPT_DIR/git-askpass.sh"
chmod 700 "$ASKPASS"
export GIT_ASKPASS="$ASKPASS"
export GIT_TERMINAL_PROMPT=0
export OPENAI_API_KEY OPENAI_BASE_URL OPENAI_MODEL

[[ -d "$TARGET_DIR/.git" ]] || {
  echo "Target repository missing. Run worker/bootstrap.sh first." >&2
  exit 1
}

PROMPT=$(cat <<'EOF'
Read TASKS/README.md first and execute the complete TASK-001 through TASK-007 chain in order.

Follow AGENTS.md and every canonical file referenced by the tasks. Work only inside this repository. Continue autonomously from one task to the next without asking for approval between normal steps. Analyze, implement, test, fix, and prepare the FCC/Codex review handoff exactly as the task files require. Stop only for a genuine blocker that cannot be resolved safely from the repository, available tools, or documented contracts.

Do not bypass gates, weaken safety rules, invent evidence, fabricate review results, or claim successful checks that were not executed. Do not use historical phase numbering as the implementation order unless a current canonical document explicitly requires it. Do not modify files outside this repository. Do not force-push. Do not push changes unless the repository instructions or the task chain explicitly require a push.

Finish by completing TASK-007 and clearly report the final state, test evidence, remaining blockers/findings, and exact recommended next step.
EOF
)

cd "$TARGET_DIR"

printf 'run_id=%s\n' "$RUN_ID" | tee "$LOG_DIR/run-metadata.txt"
printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOG_DIR/run-metadata.txt"
printf 'base_head=%s\n' "$(git rev-parse HEAD)" | tee -a "$LOG_DIR/run-metadata.txt"
printf 'model=%s\n' "$OPENAI_MODEL" | tee -a "$LOG_DIR/run-metadata.txt"
printf 'approval_mode=%s\n' "$QWEN_APPROVAL_MODE" | tee -a "$LOG_DIR/run-metadata.txt"
printf 'max_wall_time=%s\n' "$QWEN_MAX_WALL_TIME" | tee -a "$LOG_DIR/run-metadata.txt"

set +e
qwen -p "$PROMPT" \
  --model "$OPENAI_MODEL" \
  --approval-mode "$QWEN_APPROVAL_MODE" \
  --max-wall-time "$QWEN_MAX_WALL_TIME" \
  2>&1 | tee "$LOG_DIR/qwen-output.log"
qwen_status=${PIPESTATUS[0]}
set -e

{
  printf 'finished_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'qwen_exit_code=%s\n' "$qwen_status"
  printf 'final_head=%s\n' "$(git rev-parse HEAD)"
  echo
  echo '=== GIT STATUS ==='
  git status --short --branch
  echo
  echo '=== DIFF STAT ==='
  git diff --stat
  echo
  echo '=== RECENT COMMITS ==='
  git log --oneline -10
} | tee -a "$LOG_DIR/run-metadata.txt"

printf '\nQwen run log: %s\n' "$LOG_DIR/qwen-output.log"
printf 'Run metadata: %s\n' "$LOG_DIR/run-metadata.txt"
exit "$qwen_status"
