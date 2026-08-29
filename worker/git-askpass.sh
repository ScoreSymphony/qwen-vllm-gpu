#!/usr/bin/env bash
set -Eeuo pipefail

case "${1:-}" in
  *sername*)
    printf '%s\n' 'x-access-token'
    ;;
  *assword*)
    : "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
    printf '%s\n' "$GITHUB_TOKEN"
    ;;
  *)
    printf '\n'
    ;;
esac
