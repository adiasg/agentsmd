#!/usr/bin/env bash
# `agentsmd status` - report Git automation installation state.

agentsmd_cmd_status_usage() {
  cat << 'HELP'
Usage: agentsmd status

Reports agentsmd system status.

Options:
  -h, --help    Show this help message.
HELP
}

agentsmd_cmd_status() {
  case "${1:-}" in
    -h | --help)
      agentsmd_cmd_status_usage
      return 0
      ;;
  esac

  if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
    agentsmd_die "fatal: not a git repository"
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)
  local git_dir
  git_dir=$(git rev-parse --git-dir)
  if [[ "$git_dir" != /* ]]; then
    git_dir="$repo_root/$git_dir"
  fi

  local agents_md_file="${AGENTS_MD_FILE:-AGENTS.md}"
  local merge_driver_name="agentsmd"
  local hook_path="$git_dir/hooks/pre-commit"
  local attributes_path="$git_dir/info/attributes"
  local alias_key="alias.rebuild-agents"

  status_print() {
    printf '[agentsmd] %s\n' "$1"
  }

  relative_to_repo() {
    local path="$1"
    if [[ "$path" == "$repo_root"* ]]; then
      printf '%s\n' "${path#"$repo_root"/}"
    else
      printf '%s\n' "$path"
    fi
  }

  abs_path() {
    local target="$1"
    local resolved

    if command -v realpath > /dev/null 2>&1; then
      realpath "$target" 2> /dev/null || printf '%s\n' "$target"
      return
    fi

    if resolved=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target" 2> /dev/null); then
      printf '%s\n' "$resolved"
      return
    fi

    if resolved=$(perl -MCwd -e 'print Cwd::abs_path($ARGV[0])' "$target" 2> /dev/null); then
      printf '%s\n' "$resolved"
      return
    fi

    printf '%s\n' "$target"
  }

  local -a ok_checks=()
  local -a missing_checks=()

  if [ -f "$hook_path" ] && grep -q '# AGENTS_MD_MANAGEMENT' "$hook_path"; then
    ok_checks+=("pre-commit hook installed ($(relative_to_repo "$hook_path"))")
  else
    missing_checks+=("pre-commit hook missing or unmanaged at $(relative_to_repo "$hook_path")")
  fi

  if [ -f "$attributes_path" ] && grep -q "^${agents_md_file} merge=${merge_driver_name}$" "$attributes_path"; then
    ok_checks+=("merge driver registered in $(relative_to_repo "$attributes_path") for ${agents_md_file}")
  else
    missing_checks+=("merge driver entry absent for ${agents_md_file} in $(relative_to_repo "$attributes_path")")
  fi

  if git config --local --get "$alias_key" > /dev/null 2>&1; then
    ok_checks+=("git alias ${alias_key} configured")
  else
    missing_checks+=("git alias ${alias_key} not configured")
  fi

  local merge_driver_key="merge.${merge_driver_name}.driver"
  if git config --local --get "$merge_driver_key" > /dev/null 2>&1; then
    ok_checks+=("merge driver executable configured (${merge_driver_key})")
  else
    missing_checks+=("merge driver executable missing (${merge_driver_key})")
  fi

  if git ls-files --error-unmatch "$agents_md_file" > /dev/null 2>&1; then
    local ls_prefix
    ls_prefix=$(git ls-files -v "$agents_md_file" | cut -c1)
    if [ "$ls_prefix" = "h" ]; then
      ok_checks+=("${agents_md_file} marked assume-unchanged")
    else
      missing_checks+=("${agents_md_file} is tracked but not marked assume-unchanged")
    fi
  else
    missing_checks+=("${agents_md_file} not tracked by Git; cannot verify assume-unchanged flag")
  fi

  if [ ${#missing_checks[@]} -eq 0 ]; then
    status_print "Status: ENABLED"
  else
    status_print "Status: DISABLED"
  fi

  status_print "Checks:"
  local entry
  # Use ${arr+"${arr[@]}"} to avoid nounset errors on empty arrays in older Bash
  for entry in ${ok_checks+"${ok_checks[@]}"}; do
    status_print "  - [OK] $entry"
  done
  for entry in ${missing_checks+"${missing_checks[@]}"}; do
    status_print "  - [MISSING] $entry"
  done

  if [ ${#missing_checks[@]} -eq 0 ]; then
    local prefs_path="$repo_root/.agentsmd"
    local prefs_display
    prefs_display=$(abs_path "$prefs_path")
    if [ -f "$prefs_path" ]; then
      if grep -q '[^[:space:]]' "$prefs_path"; then
        status_print "Developer preferences: ${prefs_display} (present)"
      else
        status_print "Developer preferences: ${prefs_display} (empty)"
      fi
    else
      status_print "Developer preferences: ${prefs_display} (not found)"
    fi
  fi

  return 0
}

agentsmd_register_command "status" "agentsmd_cmd_status" "Report agentsmd Git automation status"
