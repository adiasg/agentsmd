#!/usr/bin/env bash
# AGENTS_MD_MANAGEMENT: Shared helpers for local AGENTS.md automation

: "${AGENTS_MD_FILE:=AGENTS.md}"
: "${AGENTS_CLI_CMD:=agentsmd}"
: "${AGENTS_CLI_ARGS:=make}"

AGENTS_REPO_ROOT=$(git rev-parse --show-toplevel 2> /dev/null || pwd)
AGENTS_GIT_DIR=$(git rev-parse --git-dir 2> /dev/null || echo ".git")
if [ "${AGENTS_GIT_DIR#/}" = "$AGENTS_GIT_DIR" ]; then
  AGENTS_GIT_DIR="$AGENTS_REPO_ROOT/$AGENTS_GIT_DIR"
fi

agents_md_log() {
  printf '[agentsmd] %s\n' "$*" >&2
}

agents_md_is_tracked() {
  git ls-files --error-unmatch "$AGENTS_MD_FILE" > /dev/null 2>&1
}

agents_md_changed_between() {
  local from_ref=$1
  local to_ref=$2
  git diff --name-only "$from_ref" "$to_ref" -- "$AGENTS_MD_FILE" 2> /dev/null | grep -Fx -- "$AGENTS_MD_FILE"
}

agents_md_was_in_stdin() {
  local line
  while IFS= read -r line; do
    if [ "$line" = "$AGENTS_MD_FILE" ]; then
      return 0
    fi
  done
  return 1
}

agents_md_render_cli() {
  local cmd="$AGENTS_CLI_CMD"
  local args_string="$AGENTS_CLI_ARGS"
  local -a args=()

  if [ -n "$args_string" ]; then
    # shellcheck disable=SC2206
    args=($args_string)
  fi

  if [ ! -x "$cmd" ]; then
    local resolved
    resolved=$(command -v "$cmd" 2> /dev/null || true)
    if [ -n "$resolved" ]; then
      cmd="$resolved"
    fi
  fi

  if ! [ -x "$cmd" ]; then
    agents_md_log "WARNING: '$AGENTS_CLI_CMD' is not executable; skipped auto-render."
    return 0
  fi

  if "$cmd" "${args[@]}"; then
    agents_md_log "Rendered $AGENTS_MD_FILE via $cmd ${args[*]}"
    agents_md_mark_assume_unchanged
  else
    agents_md_log "WARNING: $cmd ${args[*]} failed; rerun manually if needed."
  fi
}

agents_md_mark_assume_unchanged() {
  if agents_md_is_tracked; then
    git update-index --assume-unchanged "$AGENTS_MD_FILE" > /dev/null 2>&1 || true
  fi
}
