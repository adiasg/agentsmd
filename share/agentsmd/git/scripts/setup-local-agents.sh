#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ASSET_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(git rev-parse --show-toplevel 2> /dev/null || true)

if [ -z "$REPO_ROOT" ]; then
  echo "[agentsmd] ERROR: This script must be run inside a git repository." >&2
  exit 1
fi

cd "$REPO_ROOT"

GIT_DIR=$(git rev-parse --git-dir)
if [[ "$GIT_DIR" != /* ]]; then
  GIT_DIR="$REPO_ROOT/$GIT_DIR"
fi
HOOKS_DIR="$GIT_DIR/hooks"
INFO_DIR="$GIT_DIR/info"
ATTRIBUTES_FILE="$INFO_DIR/attributes"

TEMPLATE_DIR="$ASSET_ROOT/templates/hooks"
MERGE_DRIVER_NAME="agentsmd"
MERGE_DRIVER_SCRIPT="$HOOKS_DIR/agentsmd-merge-driver.sh"
COMMON_HOOK_SCRIPT="$HOOKS_DIR/agentsmd-hooks-common.sh"
STATE_DIR="$GIT_DIR/agentsmd-state"

: "${AGENTS_MD_FILE:=AGENTS.md}"
: "${AGENTS_CLI_CMD:=agentsmd}"
: "${AGENTS_CLI_ARGS:=make}"

log() {
  printf '[agentsmd] %s\n' "$1" >&2
}

state_path() {
  printf '%s/%s' "$STATE_DIR" "$1"
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
}

mark_owned() {
  ensure_state_dir
  printf 'owned\n' > "$(state_path "$1")"
}

is_owned() {
  [ -f "$(state_path "$1")" ]
}

backup_alias_if_needed() {
  local alias_command="$1"
  local alias_key="alias.rebuild-agents"
  local owner_marker="alias.rebuild-agents.owned"
  local backup_file
  backup_file=$(state_path "alias.rebuild-agents.backup")

  if is_owned "$owner_marker"; then
    rm -f "$backup_file"
    return
  fi

  local existing
  if existing=$(git config --local --get "$alias_key" 2> /dev/null); then
    ensure_state_dir
    printf '%s\n' "$existing" > "$backup_file"
  else
    rm -f "$backup_file"
  fi
}

backup_merge_config_if_needed() {
  local owner_marker="merge.${MERGE_DRIVER_NAME}.owned"
  local name_backup driver_backup
  name_backup=$(state_path "merge.${MERGE_DRIVER_NAME}.name.backup")
  driver_backup=$(state_path "merge.${MERGE_DRIVER_NAME}.driver.backup")

  if is_owned "$owner_marker"; then
    rm -f "$name_backup" "$driver_backup"
    return
  fi

  local name_key="merge.${MERGE_DRIVER_NAME}.name"
  local driver_key="merge.${MERGE_DRIVER_NAME}.driver"
  local existing

  existing=$(git config --local --get-all "$name_key" 2> /dev/null || true)
  if [ -n "$existing" ]; then
    ensure_state_dir
    printf '%s\n' "$existing" > "$name_backup"
  else
    rm -f "$name_backup"
  fi

  existing=$(git config --local --get-all "$driver_key" 2> /dev/null || true)
  if [ -n "$existing" ]; then
    ensure_state_dir
    printf '%s\n' "$existing" > "$driver_backup"
  else
    rm -f "$driver_backup"
  fi
}

write_template() {
  local template_path="$1"
  local destination_path="$2"
  local mode="$3"

  mkdir -p "$(dirname "$destination_path")"
  cp "$template_path" "$destination_path"
  chmod "$mode" "$destination_path" 2> /dev/null || true
}

install_common_assets() {
  write_template "$TEMPLATE_DIR/agentsmd-hooks-common.sh" "$COMMON_HOOK_SCRIPT" 755
  write_template "$TEMPLATE_DIR/agentsmd-merge-driver.sh" "$MERGE_DRIVER_SCRIPT" 755
}

backup_existing_hook_if_needed() {
  local hook_path="$1"
  local marker="# AGENTS_MD_MANAGEMENT"
  if [ -f "$hook_path" ] && ! grep -q "$marker" "$hook_path"; then
    local backup_path="${hook_path}.agentsmd.bak"
    if [ ! -f "$backup_path" ]; then
      mv "$hook_path" "$backup_path"
      log "Existing $(basename "$hook_path") hook moved to $(basename "$backup_path")."
    else
      log "NOTICE: Existing $(basename "$hook_path") hook already backed up at $(basename "$backup_path")."
    fi
  fi
}

install_hook() {
  local hook_name="$1"
  local template_name="$2"
  local hook_path="$HOOKS_DIR/$hook_name"
  local backup_path="${hook_path}.agentsmd.bak"

  backup_existing_hook_if_needed "$hook_path"

  write_template "$TEMPLATE_DIR/$template_name" "$hook_path" 755

  if [ -f "$backup_path" ]; then
    {
      echo ''
      echo '# AGENTS_MD_MANAGEMENT: previous hook preserved at:'
      echo '#   '"$backup_path"
    } >> "$hook_path"
  fi
}

ensure_attributes() {
  mkdir -p "$INFO_DIR"
  if [ ! -f "$ATTRIBUTES_FILE" ]; then
    : > "$ATTRIBUTES_FILE"
  fi

  if ! grep -q "^${AGENTS_MD_FILE} merge=${MERGE_DRIVER_NAME}$" "$ATTRIBUTES_FILE"; then
    printf '%s merge=%s\n' "$AGENTS_MD_FILE" "$MERGE_DRIVER_NAME" >> "$ATTRIBUTES_FILE"
    log "Added $AGENTS_MD_FILE merge driver to .git/info/attributes."
  else
    log "Attributes already configured $AGENTS_MD_FILE merge driver."
  fi
}

configure_merge_driver() {
  backup_merge_config_if_needed
  git config --local merge."$MERGE_DRIVER_NAME".name "Prefer remote $AGENTS_MD_FILE"
  git config --local merge."$MERGE_DRIVER_NAME".driver "$MERGE_DRIVER_SCRIPT %O %A %B"
  mark_owned "merge.${MERGE_DRIVER_NAME}.owned"
}

configure_aliases() {
  local cli_cmd="${AGENTS_CLI_CMD:-agentsmd}"
  local alias_command="!$cli_cmd"
  if [ -n "$AGENTS_CLI_ARGS" ]; then
    alias_command="${alias_command} $AGENTS_CLI_ARGS"
  fi
  backup_alias_if_needed "$alias_command"
  git config --local alias.rebuild-agents "$alias_command"
  mark_owned "alias.rebuild-agents.owned"
}

mark_assume_unchanged() {
  if git ls-files --error-unmatch "$AGENTS_MD_FILE" > /dev/null 2>&1; then
    if git update-index --assume-unchanged "$AGENTS_MD_FILE" 2> /dev/null; then
      log "Marked $AGENTS_MD_FILE as assume-unchanged."
    else
      log "WARNING: Unable to mark $AGENTS_MD_FILE assume-unchanged."
    fi
  else
    log "WARNING: $AGENTS_MD_FILE is not tracked; skipping assume-unchanged."
  fi
}

initial_render() {
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

  if [ ! -x "$cmd" ]; then
    log "NOTICE: Skipping initial render; '$AGENTS_CLI_CMD' is not executable."
    return
  fi

  if "$cmd" "${args[@]}"; then
    log "Initial render complete via $cmd ${args[*]}"
  else
    log "WARNING: Initial render via $cmd ${args[*]} failed; run manually if needed."
  fi
}

install_common_assets
install_hook pre-commit pre-commit.sh
install_hook post-merge post-merge.sh
install_hook post-checkout post-checkout.sh

ensure_attributes
configure_merge_driver
configure_aliases
mark_assume_unchanged
initial_render
mark_assume_unchanged

relative_hooks_dir="${HOOKS_DIR#"$REPO_ROOT"/}"
if [ "$relative_hooks_dir" = "$HOOKS_DIR" ]; then
  display_hooks_dir="$HOOKS_DIR"
else
  display_hooks_dir="$relative_hooks_dir"
fi

log "Setup complete. Hooks installed under $display_hooks_dir."
log "Use 'agentsmd make' (or 'git rebuild-agents') to regenerate on demand."

exit 0
