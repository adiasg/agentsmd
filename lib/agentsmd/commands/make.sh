#!/usr/bin/env bash
# `agentsmd make` command: regenerate AGENTS.md with local preferences.

agentsmd_cmd_make_usage() {
  cat << 'HELP'
Usage: agentsmd make [options]

Regenerates AGENTS.md at the repository root with templates and preferences
from the .agentsmd file.

Options:
  -h, --help    Show this help message.
HELP
}

agentsmd_make_strip_existing_block() {
  local src="$1"
  local dest="$2"
  local prefs="$3"

  if [ ! -f "$src" ]; then
    : > "$dest"
    return
  fi

  if [ -z "$prefs" ] || [ ! -f "$prefs" ] || ! grep -q '[^[:space:]]' "$prefs"; then
    cat "$src" > "$dest"
    return
  fi

  local prefs_tmp tail_tmp
  prefs_tmp=$(mktemp "${dest}.prefs.XXXXXX") || agentsmd_die "Unable to prepare temporary preferences copy"
  tail_tmp=$(mktemp "${dest}.tail.XXXXXX") || {
    rm -f "$prefs_tmp"
    agentsmd_die "Unable to prepare temporary tail copy"
  }

  cp "$prefs" "$prefs_tmp"
  agentsmd_make_ensure_trailing_newline "$prefs_tmp"

  local pref_lines total_lines keep_lines preceding_line
  pref_lines=$(wc -l < "$prefs_tmp" | tr -d '[:space:]')
  pref_lines=${pref_lines:-0}

  if [ "$pref_lines" -gt 0 ]; then
    tail -n "$pref_lines" "$src" > "$tail_tmp" 2> /dev/null || :
  else
    : > "$tail_tmp"
  fi

  if cmp -s "$tail_tmp" "$prefs_tmp"; then
    total_lines=$(wc -l < "$src" | tr -d '[:space:]')
    total_lines=${total_lines:-0}
    keep_lines=$((total_lines - pref_lines))

    if [ "$keep_lines" -gt 0 ]; then
      preceding_line=$(sed -n "${keep_lines}p" "$src")
      if [ -z "$preceding_line" ]; then
        keep_lines=$((keep_lines - 1))
      fi
    fi

    if [ "$keep_lines" -gt 0 ]; then
      head -n "$keep_lines" "$src" > "$dest"
    else
      : > "$dest"
    fi
  else
    cat "$src" > "$dest"
  fi

  rm -f "$prefs_tmp" "$tail_tmp"
}

agentsmd_make_ensure_trailing_newline() {
  local file="$1"
  if [ ! -s "$file" ]; then
    printf '\n' >> "$file"
    return
  fi
  local last_byte
  last_byte=$(tail -c 1 "$file" 2> /dev/null | od -An -t u1 | tr -d ' \n') || last_byte=""
  if [ "$last_byte" != "10" ]; then
    printf '\n' >> "$file"
  fi
}

agentsmd_make_normalize_single_trailing_newline() {
  local file="$1"
  # Normalize file to end with exactly one trailing newline (collapse many to one)
  if [ ! -f "$file" ]; then
    return
  fi
  local python_bin="python3"
  if ! command -v "$python_bin" > /dev/null 2>&1; then
    if command -v python > /dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' > /dev/null 2>&1; then
      python_bin="python"
    else
      agentsmd_die "Normalization requires Python 3 (python3 or python)."
    fi
  fi
  "$python_bin" "$AGENTSMD_SHARE_DIR/python/normalize_trailing_newline.py" "$file" || exit 1
}

agentsmd_make_render_templates() {
  local source="$1"
  local dest="$2"
  local repo_root="$3"
  local home_dir="${HOME:-}"
  local python_bin="python3"
  local python_output

  if ! command -v "$python_bin" > /dev/null 2>&1; then
    if command -v python > /dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' > /dev/null 2>&1; then
      python_bin="python"
    else
      agentsmd_die "Template rendering requires Python 3 (python3 or python)."
    fi
  fi

  local script_path="$AGENTSMD_SHARE_DIR/python/render_templates.py"
  python_output=$(
    $python_bin "$script_path" "$source" "$dest" "$repo_root" "$home_dir"
  ) || agentsmd_die "Unable to render templates in $source"

  if [ -n "$python_output" ]; then
    local line
    while IFS= read -r line; do
      case "$line" in
        missing\ *)
          local name
          name=${line#missing }
          agentsmd_log "WARNING: template '$name' not found; leaving token in place."
          ;;
      esac
    done << EOF
$python_output
EOF
  fi
}

agentsmd_make_write_head_snapshot() {
  local relative_path="$1"
  local dest="$2"

  if ! git rev-parse --verify HEAD > /dev/null 2>&1; then
    return 1
  fi

  if git show "HEAD:$relative_path" > "$dest" 2> /dev/null; then
    return 0
  fi

  return 1
}

agentsmd_cmd_make() {
  case "${1:-}" in
    -h | --help)
      agentsmd_cmd_make_usage
      return 0
      ;;
  esac

  local repo_root
  if ! repo_root=$(git rev-parse --show-toplevel 2> /dev/null); then
    agentsmd_die "fatal: not a git repository"
  fi

  local target="$repo_root/AGENTS.md"
  local source="$repo_root/.agentsmd"
  local tmp base_tmp render_tmp base_render_tmp
  tmp=$(mktemp "$target.XXXXXX") || agentsmd_die "Unable to create temporary file for $target"
  base_tmp=$(mktemp "$target.base.XXXXXX") || {
    rm -f "$tmp"
    agentsmd_die "Unable to stage committed base for $target"
  }
  render_tmp=$(mktemp "$target.render.XXXXXX") || {
    rm -f "$tmp" "$base_tmp"
    agentsmd_die "Unable to prepare rendered preferences for $target"
  }
  base_render_tmp=$(mktemp "$target.base.render.XXXXXX") || {
    rm -f "$tmp" "$base_tmp" "$render_tmp"
    agentsmd_die "Unable to prepare rendered base content for $target"
  }

  cleanup_make_tmp() {
    rm -f "$tmp" "$base_tmp" "$render_tmp"
  }
  trap cleanup_make_tmp EXIT

  local rendered_source=""
  local have_source=0
  if [ -f "$source" ]; then
    have_source=1
    agentsmd_make_render_templates "$source" "$render_tmp" "$repo_root"
    rendered_source="$render_tmp"
    # Ensure preferences end with exactly one trailing newline
    agentsmd_make_normalize_single_trailing_newline "$rendered_source"
  fi

  local relative_target="AGENTS.md"
  if ! agentsmd_make_write_head_snapshot "$relative_target" "$base_tmp"; then
    if [ -f "$target" ]; then
      cat "$target" > "$base_tmp"
    else
      : > "$base_tmp"
    fi
  fi

  if [ -s "$base_tmp" ]; then
    agentsmd_make_strip_existing_block "$base_tmp" "$tmp" "$rendered_source"
  else
    : > "$tmp"
  fi
  rm -f "$base_tmp"

  # Render templates present in the base content
  agentsmd_make_render_templates "$tmp" "$base_render_tmp" "$repo_root"
  mv "$base_render_tmp" "$tmp"

  if [ "$have_source" -eq 1 ]; then
    if grep -q '[^[:space:]]' "$rendered_source"; then
      if [ -s "$tmp" ]; then
        # Normalize base to exactly one trailing newline, then add a blank line
        agentsmd_make_normalize_single_trailing_newline "$tmp"
        printf '\n' >> "$tmp"
      fi
      # Append preferences (already normalized to a single trailing newline)
      cat "$rendered_source" >> "$tmp"
      # Ensure final file ends with a single trailing newline
      agentsmd_make_normalize_single_trailing_newline "$tmp"
    else
      agentsmd_log "NOTICE: .agentsmd is empty; skipping local preferences block."
    fi
  else
    agentsmd_log "NOTICE: .agentsmd not found; skipping local preferences block."
  fi

  if ! mv "$tmp" "$target"; then
    agentsmd_die "Unable to write $target"
  fi
  trap - EXIT
  cleanup_make_tmp

  agentsmd_log "Generated $target file."
}

agentsmd_register_command "make" "agentsmd_cmd_make" "Regenerate AGENTS.md with .agentsmd preferences"
