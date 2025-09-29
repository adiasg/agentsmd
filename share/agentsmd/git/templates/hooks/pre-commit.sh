#!/usr/bin/env bash
set -euo pipefail
# AGENTS_MD_MANAGEMENT: pre-commit guard

HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$HOOK_DIR/agentsmd-hooks-common.sh"

if ! agents_md_is_tracked; then
  exit 0
fi

if git diff --cached --name-only -- "$AGENTS_MD_FILE" | grep -Fx -- "$AGENTS_MD_FILE"; then
  agents_md_log "ERROR: $AGENTS_MD_FILE must not be committed. Use 'git reset HEAD -- $AGENTS_MD_FILE' to unstage."
  exit 1
fi

exit 0
