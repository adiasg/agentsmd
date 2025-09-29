#!/usr/bin/env bash
# Core runtime: command registration, dispatch, and helpers shared by the CLI.

set -euo pipefail
IFS=$'\n\t'

: "${AGENTSMD_ROOT:?AGENTSMD_ROOT must be set by the entrypoint}"
: "${AGENTSMD_LIB_DIR:=$AGENTSMD_ROOT/lib/agentsmd}"
: "${AGENTSMD_SHARE_DIR:=$AGENTSMD_ROOT/share/agentsmd}"

AGENTSMD_COMMANDS=()
AGENTSMD_COMMAND_FUNCS=()
AGENTSMD_COMMAND_SUMMARIES=()

agentsmd_git_assets_dir() {
  printf '%s\n' "$AGENTSMD_SHARE_DIR/git"
}

agentsmd_register_command() {
  local name="$1"
  local func="$2"
  local summary="$3"
  AGENTSMD_COMMANDS+=("$name")
  AGENTSMD_COMMAND_FUNCS+=("$func")
  AGENTSMD_COMMAND_SUMMARIES+=("$summary")
}

agentsmd_log() {
  local message="$*"
  if [ "${AGENTSMD_QUIET:-0}" = "1" ] && [[ "$message" != ERROR:* ]]; then
    return
  fi
  printf '[agentsmd] %s\n' "$message" >&2
}

agentsmd_die() {
  agentsmd_log "ERROR: $*"
  exit 1
}

agentsmd_version() {
  if [ -n "${AGENTSMD_VERSION:-}" ]; then
    printf '%s\n' "$AGENTSMD_VERSION"
    return
  fi
  local package_json="${AGENTSMD_ROOT}/package.json"
  if [ -f "$package_json" ]; then
    local package_version
    package_version=$(awk -F'"' '/"version"[[:space:]]*:/ {print $4; exit}' "$package_json")
    if [ -n "$package_version" ]; then
      AGENTSMD_VERSION="$package_version"
      printf '%s\n' "$AGENTSMD_VERSION"
      return
    fi
  fi

  local version_file="${AGENTSMD_ROOT}/VERSION"
  if [ -f "$version_file" ]; then
    AGENTSMD_VERSION=$(sed -n '1p' "$version_file")
    if [ -n "$AGENTSMD_VERSION" ]; then
      printf '%s\n' "$AGENTSMD_VERSION"
      return
    fi
  fi

  AGENTSMD_VERSION='0.0.0-dev'
  printf '%s\n' "$AGENTSMD_VERSION"
}

agentsmd_usage() {
  cat << 'USAGE'
Usage: agentsmd <command> [options]

Commands:
USAGE
  local i
  for i in "${!AGENTSMD_COMMANDS[@]}"; do
    printf '  %-20s %s\n' "${AGENTSMD_COMMANDS[$i]}" "${AGENTSMD_COMMAND_SUMMARIES[$i]}"
  done
  printf "\nUse \`agentsmd help <command>\` to view command-specific help.\n"
}

agentsmd_command_help() {
  local command="$1"
  local func
  func=$(agentsmd_lookup_function "$command") || return
  if command -v "$func" > /dev/null 2>&1; then
    "$func" --help
  else
    agentsmd_die "Command handler for '$command' is not executable."
  fi
}

agentsmd_lookup_function() {
  local name="$1"
  local i
  for i in "${!AGENTSMD_COMMANDS[@]}"; do
    if [ "${AGENTSMD_COMMANDS[$i]}" = "$name" ]; then
      printf '%s\n' "${AGENTSMD_COMMAND_FUNCS[$i]}"
      return 0
    fi
  done
  agentsmd_die "Unknown command '$name'"
}

agentsmd_dispatch() {
  local command="$1"
  shift
  local func
  func=$(agentsmd_lookup_function "$command")
  "$func" "$@"
}

agentsmd_load_commands() {
  local file
  for file in "$AGENTSMD_LIB_DIR"/commands/*.sh; do
    [ -r "$file" ] || continue
    # shellcheck source=/dev/null
    . "$file"
  done
}

agentsmd_main() {
  agentsmd_load_commands
  if [ $# -eq 0 ]; then
    agentsmd_usage
    exit 0
  fi

  case "$1" in
    -h | --help)
      agentsmd_usage
      exit 0
      ;;
    --version)
      agentsmd_version
      exit 0
      ;;
    help)
      shift
      if [ $# -eq 0 ]; then
        agentsmd_usage
      else
        agentsmd_command_help "$1"
      fi
      exit 0
      ;;
  esac

  local cmd="$1"
  shift
  agentsmd_dispatch "$cmd" "$@"
}
