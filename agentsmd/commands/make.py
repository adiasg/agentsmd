"""Implementation of the `agentsmd make` command."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path
from typing import Iterable

from ..runtime import die, ensure_repo_root, log, read_file, write_file

HELP_TEXT = """Usage: agentsmd make [options]

Regenerates AGENTS.md at the repository root with templates and preferences
from the .agentsmd file.

Options:
  -h, --help    Show this help message.
"""

SUMMARY = "Regenerate AGENTS.md with .agentsmd preferences"

TEMPLATE_PATTERN = re.compile(r"{{\s*([A-Za-z0-9._-]+)\s*}}")


def run(argv: list[str]) -> int:
    if argv and argv[0] in {"-h", "--help"}:
        print(HELP_TEXT, end="")
        return 0
    if argv:
        die(f"Unknown option for make command: {' '.join(argv)}")

    repo_root = ensure_repo_root()
    target = repo_root / "AGENTS.md"
    preferences_path = repo_root / ".agentsmd"

    home_dir_str = os.environ.get("HOME")
    home_dir = Path(home_dir_str) if home_dir_str else None

    preferences_content, prefs_warnings, prefs_present = render_preferences(
        preferences_path, home_dir
    )
    base_content = determine_base_content(repo_root, target)

    if prefs_present:
        base_without_trailer = strip_existing_block(base_content, preferences_content)
    else:
        base_without_trailer = base_content

    rendered_base, base_warnings = render_templates(
        base_without_trailer, home_dir
    )

    emit_template_warnings(base_warnings)
    emit_template_warnings(prefs_warnings)

    output = compose_output(rendered_base, preferences_content, prefs_present)
    write_file(target, output)
    log(f"Generated {target} file.")
    return 0


def render_preferences(
    path: Path, home_dir: Path | None
) -> tuple[str, set[str], bool]:
    if not path.is_file():
        log("NOTICE: .agentsmd not found; skipping local preferences block.")
        return ("", set(), False)

    raw = read_file(path)
    rendered, warnings = render_templates(raw, home_dir)
    has_content = bool(rendered) and bool(re.search(r"\S", rendered))

    if not has_content:
        log("NOTICE: .agentsmd is empty; skipping local preferences block.")
        return ("", warnings, False)

    rendered = normalize_single_trailing_newline(rendered)
    return (rendered, warnings, True)


def determine_base_content(repo_root: Path, target: Path) -> str:
    head_content = read_head_snapshot(repo_root, "AGENTS.md")
    if head_content is not None:
        return head_content
    if target.is_file():
        return read_file(target)
    return ""


def strip_existing_block(base: str, preferences: str) -> str:
    if not preferences:
        return base
    base_lines = base.splitlines(keepends=True)
    pref_lines = preferences.splitlines(keepends=True)
    if len(pref_lines) == 0 or len(base_lines) < len(pref_lines):
        return base
    tail = base_lines[-len(pref_lines):]
    if tail != pref_lines:
        return base
    keep_count = len(base_lines) - len(pref_lines)
    if keep_count > 0:
        preceding_line = base_lines[keep_count - 1]
        if preceding_line.strip() == "":
            keep_count -= 1
    if keep_count <= 0:
        return ""
    return "".join(base_lines[:keep_count])


def render_templates(content: str, home_dir: Path | None) -> tuple[str, set[str]]:
    if not content:
        return "", set()

    warnings: set[str] = set()
    parts: list[str] = []
    cursor = 0

    for match in TEMPLATE_PATTERN.finditer(content):
        parts.append(content[cursor:match.start()])
        template_name = match.group(1)
        resolved = resolve_template(template_name, home_dir)
        if resolved is None:
            warnings.add(template_name)
            parts.append(match.group(0))
            cursor = match.end()
            continue

        template_body = resolved.strip("\n")
        has_template_content = bool(template_body)

        if has_template_content:
            prefix_text = "".join(parts)
            if prefix_text.strip():
                _remove_trailing_newlines(parts)
                parts.append("\n\n")

            parts.append(template_body)

        suffix = content[match.end():]
        if suffix.strip():
            if has_template_content:
                parts.append("\n\n")
                cursor = match.end() + _count_leading_newline_chars(suffix)
            else:
                cursor = match.end()
        else:
            if has_template_content:
                parts.append("\n")
            cursor = len(content)
            break

    parts.append(content[cursor:])
    rendered = "".join(parts)
    return rendered, warnings


def _remove_trailing_newlines(parts: list[str]) -> None:
    while parts:
        segment = parts[-1]
        if not segment:
            parts.pop()
            continue
        if segment.endswith("\n"):
            trimmed = segment.rstrip("\n")
            if trimmed:
                parts[-1] = trimmed
                return
            parts.pop()
            continue
        return


def _count_leading_newline_chars(text: str) -> int:
    index = 0
    length = len(text)
    while index < length:
        if text.startswith("\r\n", index):
            index += 2
        elif text.startswith("\n", index):
            index += 1
        else:
            break
    return index


def resolve_template(name: str, home_dir: Path | None) -> str | None:
    if home_dir is None:
        return None
    templates_dir = home_dir / ".agentsmd" / "templates"
    for candidate in (templates_dir / name, templates_dir / f"{name}.md"):
        if candidate.is_file():
            return read_file(candidate)
    return None


def emit_template_warnings(warnings: Iterable[str]) -> None:
    for template in sorted(set(warnings)):
        log(f"WARNING: template '{template}' not found; leaving token in place.")


def compose_output(base: str, preferences: str, has_preferences: bool) -> str:
    base = base or ""
    preferences = preferences or ""

    base = normalize_single_trailing_newline(base) if base else ""

    if not has_preferences:
        return base

    prefs_body = normalize_single_trailing_newline(preferences)

    segments: list[str] = []
    if base:
        segments.append(base.rstrip("\n"))
    if base and prefs_body:
        segments.append("")
    if prefs_body:
        segments.append(prefs_body.rstrip("\n"))
    if not segments:
        return ""
    return "\n".join(segments) + "\n"


def normalize_single_trailing_newline(content: str) -> str:
    if not content:
        return ""
    stripped = content.rstrip("\n")
    return stripped + "\n"


def read_head_snapshot(repo_root: Path, relative_path: str) -> str | None:
    completed = subprocess.run(
        ["git", "show", f"HEAD:{relative_path}"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        return None
    return completed.stdout
