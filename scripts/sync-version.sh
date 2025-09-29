#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if ! command -v node > /dev/null 2>&1; then
  echo "[version] node is required to synchronize VERSION" >&2
  exit 1
fi

pkg_version=$(node -p "require('./package.json').version" 2> /dev/null)

if [ -z "${pkg_version:-}" ]; then
  echo "[version] unable to read version from package.json" >&2
  exit 1
fi

printf '%s\n' "$pkg_version" > VERSION

if command -v git > /dev/null 2>&1 && git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  git add VERSION
fi

echo "[version] synchronized VERSION -> $pkg_version"
