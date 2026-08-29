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
TARGET_REPO="${TARGET_REPO:-https://github.com/ScoreSymphony/ScoreSymphony-Agent-VPS.git}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
TARGET_DIR="${TARGET_DIR:-$HOME/scoresymphony-workspace/scoresymphony-infrastructure}"
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-ScoreSymphony}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-scoresymphony@gmail.com}"

for cmd in curl git bash; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

install_qwen() {
  if command -v qwen >/dev/null 2>&1; then
    echo "Qwen Code already installed: $(qwen --version 2>/dev/null || echo unknown)"
    return
  fi

  echo "Installing Qwen Code using the official standalone installer..."
  installer="$(mktemp)"
  trap 'rm -f "$installer"' RETURN
  curl -fsSL \
    https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh \
    -o "$installer"
  bash "$installer"
  rm -f "$installer"
  trap - RETURN

  export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
  command -v qwen >/dev/null 2>&1 || {
    echo "Qwen Code installation completed but qwen is not on PATH." >&2
    exit 1
  }
  echo "Qwen Code installed: $(qwen --version 2>/dev/null || echo unknown)"
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    echo "uv already installed: $(uv --version 2>/dev/null || echo unknown)"
    return
  fi

  echo "Installing uv..."
  installer="$(mktemp)"
  trap 'rm -f "$installer"' RETURN
  curl -LsSf https://astral.sh/uv/install.sh -o "$installer"
  sh "$installer"
  rm -f "$installer"
  trap - RETURN

  export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
  command -v uv >/dev/null 2>&1 || {
    echo "uv installation completed but uv is not on PATH." >&2
    exit 1
  }
  echo "uv installed: $(uv --version 2>/dev/null || echo unknown)"
}

install_qwen
install_uv

ASKPASS="$SCRIPT_DIR/git-askpass.sh"
chmod 700 "$ASKPASS"
export GIT_ASKPASS="$ASKPASS"
export GIT_TERMINAL_PROMPT=0

mkdir -p "$(dirname -- "$TARGET_DIR")"

if [[ ! -d "$TARGET_DIR/.git" ]]; then
  echo "Cloning $TARGET_REPO -> $TARGET_DIR"
  git clone --branch "$TARGET_BRANCH" --single-branch "$TARGET_REPO" "$TARGET_DIR"
else
  echo "Repository already exists: $TARGET_DIR"
  if [[ -n "$(git -C "$TARGET_DIR" status --porcelain)" ]]; then
    echo "Existing repository is dirty; preserving local changes and skipping pull."
  else
    git -C "$TARGET_DIR" fetch origin "$TARGET_BRANCH"
    git -C "$TARGET_DIR" checkout "$TARGET_BRANCH"
    git -C "$TARGET_DIR" pull --ff-only origin "$TARGET_BRANCH"
  fi
fi

git -C "$TARGET_DIR" config user.name "$GIT_AUTHOR_NAME"
git -C "$TARGET_DIR" config user.email "$GIT_AUTHOR_EMAIL"

if [[ ! -f "$TARGET_DIR/TASKS/README.md" ]]; then
  echo "TASKS/README.md is missing in the target repository." >&2
  exit 1
fi

printf '\n=== WORKER BOOTSTRAP READY ===\n'
printf 'target_dir=%s\n' "$TARGET_DIR"
printf 'branch=%s\n' "$(git -C "$TARGET_DIR" branch --show-current)"
printf 'head=%s\n' "$(git -C "$TARGET_DIR" rev-parse HEAD)"
printf 'qwen=%s\n' "$(qwen --version 2>/dev/null || echo unknown)"
printf 'uv=%s\n' "$(uv --version 2>/dev/null || echo unknown)"
