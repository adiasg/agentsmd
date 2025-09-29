#!/usr/bin/env bash
# `agentsmd disable` - remove Git automation for AGENTS.md.

agentsmd_cmd_disable_usage() {
  cat << 'HELP'
Usage: agentsmd disable [options]

Removes Git hooks, merge driver configuration, and aliases installed by
`agentsmd enable`.

Options:
  -h, --help    Show this help message.
HELP
}

agentsmd_cmd_disable() {
  case "${1:-}" in
    -h | --help)
      agentsmd_cmd_disable_usage
      return 0
      ;;
  esac

  if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
    agentsmd_die "fatal: not a git repository"
  fi

  local script
  script="$(agentsmd_git_assets_dir)/scripts/disable-local-agents.sh"
  if [ ! -x "$script" ]; then
    agentsmd_die "Unable to locate disable script at $script"
  fi

  AGENTS_MD_FILE="${AGENTS_MD_FILE:-AGENTS.md}" "$script" "$@"
}

agentsmd_register_command "disable" "agentsmd_cmd_disable" "Remove Git automation for AGENTS.md"
