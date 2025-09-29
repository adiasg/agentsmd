#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if command -v shellcheck > /dev/null 2>&1; then
  mapfile -t shell_files < <(find bin lib share -type f \( -name '*.sh' -o -name '*hook' -o -name 'agentsmd' \))
  if [ "${#shell_files[@]}" -gt 0 ]; then
    shellcheck "${shell_files[@]}"
  fi
else
  echo "[lint] shellcheck not found; skipping shell lint." >&2
fi

if command -v shfmt > /dev/null 2>&1; then
  shfmt -d -i 2 -ci -sr bin lib share scripts
else
  echo "[lint] shfmt not found; skipping format check." >&2
fi
