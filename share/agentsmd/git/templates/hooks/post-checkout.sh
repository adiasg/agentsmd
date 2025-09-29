#!/usr/bin/env bash
set -euo pipefail
# AGENTS_MD_MANAGEMENT: post-checkout auto-render

HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$HOOK_DIR/agentsmd-hooks-common.sh"

if ! agents_md_is_tracked; then
  exit 0
fi

checkout_type=${3:-}
changed=false

if [ "$checkout_type" = "1" ]; then
  from_ref=${1:-}
  to_ref=${2:-}
  if [ -z "$from_ref" ] || [ -z "$to_ref" ]; then
    changed=true
  elif [ "$from_ref" = "$to_ref" ]; then
    changed=true
  elif agents_md_changed_between "$from_ref" "$to_ref"; then
    changed=true
  fi
else
  if agents_md_was_in_stdin; then
    changed=true
  fi
fi

if [ "$changed" = true ]; then
  agents_md_render_cli
else
  agents_md_mark_assume_unchanged
fi

exit 0
