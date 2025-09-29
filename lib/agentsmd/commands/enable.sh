#!/usr/bin/env bash
# `agentsmd enable` - install Git automation for AGENTS.md.

agentsmd_cmd_enable_usage() {
  cat << 'HELP'
Usage: agentsmd enable [options]

Installs Git hooks, merge drivers, and aliases that keep AGENTS.md managed by
agentsmd.

Options:
  -h, --help    Show this help message.
HELP
}

agentsmd_cmd_enable() {
  case "${1:-}" in
    -h | --help)
      agentsmd_cmd_enable_usage
      return 0
      ;;
  esac

  if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
    agentsmd_die "fatal: not a git repository"
  fi

  local script
  script="$(agentsmd_git_assets_dir)/scripts/setup-local-agents.sh"
  if [ ! -x "$script" ]; then
    agentsmd_die "Unable to locate setup script at $script"
  fi

  AGENTS_CLI_CMD="${AGENTS_CLI_CMD:-$AGENTSMD_ROOT/bin/agentsmd}" \
    AGENTS_CLI_ARGS="${AGENTS_CLI_ARGS:-make}" \
    "$script" "$@"
}

agentsmd_register_command "enable" "agentsmd_cmd_enable" "Install Git automation for AGENTS.md"
