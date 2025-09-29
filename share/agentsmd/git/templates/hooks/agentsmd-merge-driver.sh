#!/usr/bin/env bash
set -euo pipefail
# AGENTS_MD_MANAGEMENT: merge driver (prefer "theirs")

current=${2:-}
other=${3:-}

if [ -z "$current" ] || [ -z "$other" ]; then
  exit 0
fi

if command -v cp > /dev/null 2>&1; then
  cp "$other" "$current"
else
  cat "$other" > "$current"
fi

exit 0
