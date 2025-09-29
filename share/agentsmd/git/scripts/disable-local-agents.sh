#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2> /dev/null || true)

if [ -z "$REPO_ROOT" ]; then
  echo "[agentsmd] ERROR: This script must be run inside a git repository." >&2
  exit 1
fi

cd "$REPO_ROOT"

: "${AGENTS_MD_FILE:=AGENTS.md}"

GIT_DIR=$(git rev-parse --git-dir)
if [[ "$GIT_DIR" != /* ]]; then
  GIT_DIR="$REPO_ROOT/$GIT_DIR"
fi
HOOKS_DIR="$GIT_DIR/hooks"
INFO_DIR="$GIT_DIR/info"
ATTRIBUTES_FILE="$INFO_DIR/attributes"
MERGE_DRIVER_NAME="agentsmd"
STATE_DIR="$GIT_DIR/agentsmd-state"

log() {
  printf '[agentsmd] %s\n' "$1" >&2
}

state_path() {
  printf '%s/%s' "$STATE_DIR" "$1"
}

restore_config_key() {
  local key="$1"
  local backup_file="$2"

  git config --local --unset-all "$key" 2> /dev/null || true

  if [ -f "$backup_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      git config --local --add "$key" "$line" 2> /dev/null || true
    done < "$backup_file"
    rm -f "$backup_file"
    return 0
  fi

  return 1
}

cleanup_state_marker() {
  rm -f "$(state_path "$1")"
}

restore_backup_hook() {
  local hook_name="$1"
  local hook_path="$HOOKS_DIR/$hook_name"
  local backup_path="${hook_path}.agentsmd.bak"

  if [ -f "$hook_path" ] && grep -q '# AGENTS_MD_MANAGEMENT' "$hook_path"; then
    rm -f "$hook_path"
    log "Removed managed $hook_name hook."
  fi

  if [ -f "$backup_path" ]; then
    mv "$backup_path" "$hook_path"
    chmod 755 "$hook_path" 2> /dev/null || true
    log "Restored previous $hook_name hook from backup."
  fi
}

remove_hook() {
  local hook_name="$1"
  local hook_path="$HOOKS_DIR/$hook_name"
  if [ -f "$hook_path" ] && grep -q '# AGENTS_MD_MANAGEMENT' "$hook_path"; then
    rm -f "$hook_path"
    log "Removed managed $hook_name hook."
  fi
}

cleanup_hooks() {
  restore_backup_hook pre-commit
  remove_hook post-merge
  remove_hook post-checkout
  rm -f "$HOOKS_DIR/agentsmd-hooks-common.sh" "$HOOKS_DIR/agentsmd-merge-driver.sh"
}

cleanup_attributes() {
  if [ -f "$ATTRIBUTES_FILE" ]; then
    local tmp_attr
    tmp_attr=$(mktemp "$ATTRIBUTES_FILE.XXXXXX")
    local pattern="^${AGENTS_MD_FILE} merge=${MERGE_DRIVER_NAME}$"
    if grep -q "$pattern" "$ATTRIBUTES_FILE"; then
      if ! grep -v "$pattern" "$ATTRIBUTES_FILE" > "$tmp_attr"; then
        : > "$tmp_attr"
      fi
      mv "$tmp_attr" "$ATTRIBUTES_FILE"
      log "Removed merge driver entry from .git/info/attributes."
    else
      rm -f "$tmp_attr"
    fi
  fi
}

cleanup_merge_driver_config() {
  local owner_marker="merge.${MERGE_DRIVER_NAME}.owned"
  local restored=0

  if restore_config_key "merge.${MERGE_DRIVER_NAME}.name" "$(state_path "merge.${MERGE_DRIVER_NAME}.name.backup")"; then
    restored=1
  fi

  if restore_config_key "merge.${MERGE_DRIVER_NAME}.driver" "$(state_path "merge.${MERGE_DRIVER_NAME}.driver.backup")"; then
    restored=1
  fi

  cleanup_state_marker "$owner_marker"

  if [ "$restored" -eq 1 ]; then
    log "Restored merge driver configuration from backup."
  fi
}

cleanup_aliases() {
  local backup_file
  backup_file=$(state_path "alias.rebuild-agents.backup")
  local owner_marker="alias.rebuild-agents.owned"

  if [ -f "$backup_file" ]; then
    local value
    value=$(cat "$backup_file")
    rm -f "$backup_file"
    git config --local --unset-all alias.rebuild-agents 2> /dev/null || true
    git config --local alias.rebuild-agents "$value" 2> /dev/null || true
    log "Restored alias.rebuild-agents from backup."
  else
    git config --local --unset alias.rebuild-agents 2> /dev/null || true
    git config --local --unset-all alias.rebuild-agents 2> /dev/null || true
  fi

  cleanup_state_marker "$owner_marker"
}

cleanup_index_flags() {
  if git ls-files --error-unmatch "$AGENTS_MD_FILE" > /dev/null 2>&1; then
    git update-index --no-assume-unchanged "$AGENTS_MD_FILE" 2> /dev/null || true
  fi
}

cleanup_hooks
cleanup_attributes
cleanup_merge_driver_config
cleanup_aliases
cleanup_index_flags

if [ -d "$STATE_DIR" ]; then
  rmdir "$STATE_DIR" 2> /dev/null || true
fi

log "Git automation disabled. Manual AGENTS.md commits are now unmanaged."
exit 0
