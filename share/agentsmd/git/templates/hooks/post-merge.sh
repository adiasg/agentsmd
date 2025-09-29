#!/usr/bin/env bash
set -euo pipefail
# AGENTS_MD_MANAGEMENT: post-merge auto-render

HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$HOOK_DIR/agentsmd-hooks-common.sh"

if ! agents_md_is_tracked; then
  exit 0
fi

prev_head=$(git rev-parse 'HEAD@{1}' 2> /dev/null || true)

if [ -z "${prev_head:-}" ]; then
  agents_md_render_cli
  exit 0
fi

if agents_md_changed_between "$prev_head" HEAD; then
  agents_md_render_cli
else
  agents_md_mark_assume_unchanged
fi

exit 0
