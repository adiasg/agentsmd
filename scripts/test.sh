#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if command -v bats > /dev/null 2>&1; then
  bats tests/specs
else
  echo "[test] Bats not installed; skipping shell tests." >&2
fi
