#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if command -v ruff > /dev/null 2>&1; then
  ruff check agentsmd tests
else
  echo "[lint] ruff not found; skipping Python lint." >&2
fi

PYTHON_BIN=${PYTHON_BIN:-python3}
if command -v "$PYTHON_BIN" > /dev/null 2>&1; then
  export PYTHONPYCACHEPREFIX="$ROOT_DIR/.pycache"
  if ! "$PYTHON_BIN" -m compileall -q agentsmd tests > /dev/null 2>&1; then
    echo "[lint] compileall reported an error." >&2
  fi
else
  echo "[lint] python interpreter not found; skipping bytecode check." >&2
fi

if command -v shellcheck > /dev/null 2>&1; then
  mapfile -t shell_files < <(find share scripts -type f \( -name '*.sh' -o -name '*hook' \))
  if [ "${#shell_files[@]}" -gt 0 ]; then
    shellcheck "${shell_files[@]}"
  fi
else
  echo "[lint] shellcheck not found; skipping shell lint." >&2
fi

if command -v shfmt > /dev/null 2>&1; then
  shfmt -d -i 2 -ci -sr share scripts
else
  echo "[lint] shfmt not found; skipping shell format check." >&2
fi
