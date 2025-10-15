"""Implementation of the `agentsmd status` command."""

from __future__ import annotations

import subprocess
from pathlib import Path

from ..git_tools import (
    GitContext,
    build_git_context,
    git_ls_files,
    is_managed_hook,
    read_git_config,
)
from ..runtime import die, ensure_repo_root, log

HELP_TEXT = """Usage: agentsmd status

Reports agentsmd system status.

Options:
  -h, --help    Show this help message.
"""

SUMMARY = "Report agentsmd Git automation status"

MERGE_DRIVER_NAME = "agentsmd"


def run(argv: list[str]) -> int:
    if argv and argv[0] in {"-h", "--help"}:
        print(HELP_TEXT, end="")
        return 0
    if argv:
        die(f"Unknown option for status command: {' '.join(argv)}")

    repo_root = ensure_repo_root()
    ctx = build_git_context(repo_root)

    ok_checks: list[str] = []
    missing_checks: list[str] = []

    pre_commit_hook = ctx.hooks_dir / "pre-commit"
    if is_managed_hook(pre_commit_hook):
        ok_checks.append(f"pre-commit hook installed ({_relative(ctx, pre_commit_hook)})")
    else:
        missing_checks.append(
            f"pre-commit hook missing or unmanaged at {_relative(ctx, pre_commit_hook)}"
        )

    if has_merge_driver_entry(ctx):
        ok_checks.append(
            f"merge driver registered in {_relative(ctx, ctx.attributes_file)} for {ctx.agents_md_file}"
        )
    else:
        missing_checks.append(
            f"merge driver entry absent for {ctx.agents_md_file} in {_relative(ctx, ctx.attributes_file)}"
        )

    alias_value = read_git_config(ctx, "alias.rebuild-agents")
    if alias_value is not None:
        ok_checks.append("git alias alias.rebuild-agents configured")
    else:
        missing_checks.append("git alias alias.rebuild-agents not configured")

    merge_driver_key = f"merge.{MERGE_DRIVER_NAME}.driver"
    merge_driver_value = read_git_config(ctx, merge_driver_key)
    if merge_driver_value is not None:
        ok_checks.append(f"merge driver executable configured ({merge_driver_key})")
    else:
        missing_checks.append(f"merge driver executable missing ({merge_driver_key})")

    agents_md_status(ctx, ok_checks, missing_checks)

    if not missing_checks:
        log("Status: ENABLED")
    else:
        log("Status: DISABLED")

    log("Checks:")
    for entry in ok_checks:
        log(f"  - [OK] {entry}")
    for entry in missing_checks:
        log(f"  - [MISSING] {entry}")

    if not missing_checks:
        preferences_summary(ctx)

    return 0


def _relative(ctx: GitContext, path: Path) -> str:
    try:
        return str(path.relative_to(ctx.repo_root))
    except ValueError:
        return str(path)


def has_merge_driver_entry(ctx: GitContext) -> bool:
    attributes = ctx.attributes_file
    if not attributes.exists():
        return False
    entry = f"{ctx.agents_md_file} merge={MERGE_DRIVER_NAME}"
    try:
        lines = attributes.read_text(encoding="utf-8").splitlines()
    except OSError:
        return False
    return entry in lines


def agents_md_status(ctx: GitContext, ok_checks: list[str], missing_checks: list[str]) -> None:
    if not git_ls_files(ctx, ctx.agents_md_file):
        missing_checks.append(
            f"{ctx.agents_md_file} not tracked by Git; cannot verify assume-unchanged flag"
        )
        return

    result = subprocess.run(
        ["git", "ls-files", "-v", "--", ctx.agents_md_file],
        cwd=ctx.repo_root,
        capture_output=True,
        text=True,
    )
    prefix = result.stdout[:1]
    if prefix == "h":
        ok_checks.append(f"{ctx.agents_md_file} marked assume-unchanged")
    else:
        missing_checks.append(f"{ctx.agents_md_file} is tracked but not marked assume-unchanged")


def preferences_summary(ctx: GitContext) -> None:
    prefs_path = ctx.repo_root / ".agentsmd"
    resolved = prefs_path.resolve()
    if not prefs_path.exists():
        log(f"Developer preferences: {resolved} (not found)")
        return

    try:
        content = prefs_path.read_text(encoding="utf-8")
    except OSError:
        log(f"Developer preferences: {resolved} (unreadable)")
        return

    if content and any(not ch.isspace() for ch in content):
        log(f"Developer preferences: {resolved} (present)")
    else:
        log(f"Developer preferences: {resolved} (empty)")
