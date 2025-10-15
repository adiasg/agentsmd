"""Implementation of the `agentsmd disable` command."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from ..git_tools import (
    GitContext,
    build_git_context,
    git_ls_files,
    is_managed_hook,
)
from ..runtime import die, ensure_repo_root, log

HELP_TEXT = """Usage: agentsmd disable [options]

Removes Git hooks, merge driver configuration, and aliases installed by
`agentsmd enable`.

Options:
  -h, --help    Show this help message.
"""

SUMMARY = "Remove Git automation for AGENTS.md"

MERGE_DRIVER_NAME = "agentsmd"


def run(argv: list[str]) -> int:
    if argv and argv[0] in {"-h", "--help"}:
        print(HELP_TEXT, end="")
        return 0
    if argv:
        die(f"Unknown option for disable command: {' '.join(argv)}")

    repo_root = ensure_repo_root()
    ctx = build_git_context(repo_root)

    cleanup_hooks(ctx)
    cleanup_attributes(ctx)
    cleanup_merge_driver_config(ctx)
    cleanup_aliases(ctx)
    cleanup_index_flags(ctx)
    restore_canonical_agents_md(ctx)
    remove_state_dir(ctx)

    log("Removed all installed agentsmd Git automation.")
    return 0


def cleanup_hooks(ctx: GitContext) -> None:
    restore_backup_hook(ctx, "pre-commit")
    remove_hook(ctx, "post-merge")
    remove_hook(ctx, "post-checkout")
    for helper in ("agentsmd-hooks-common.sh", "agentsmd-merge-driver.sh"):
        try:
            (ctx.hooks_dir / helper).unlink()
        except FileNotFoundError:
            pass


def restore_backup_hook(ctx: GitContext, hook_name: str) -> None:
    hook_path = ctx.hooks_dir / hook_name
    backup_path = hook_path.with_suffix(".agentsmd.bak")

    if is_managed_hook(hook_path):
        hook_path.unlink()
        log(f"Removed managed {hook_name} hook.")

    if backup_path.exists():
        backup_path.rename(hook_path)
        try:
            os.chmod(hook_path, 0o755)
        except OSError:
            pass
        log(f"Restored previous {hook_name} hook from backup.")


def remove_hook(ctx: GitContext, hook_name: str) -> None:
    hook_path = ctx.hooks_dir / hook_name
    if is_managed_hook(hook_path):
        hook_path.unlink()
        log(f"Removed managed {hook_name} hook.")


def cleanup_attributes(ctx: GitContext) -> None:
    attributes = ctx.attributes_file
    if not attributes.exists():
        return
    entry = f"{ctx.agents_md_file} merge={MERGE_DRIVER_NAME}"
    lines = [line for line in attributes.read_text(encoding="utf-8").splitlines() if line]
    if entry not in lines:
        return
    filtered = [line for line in lines if line != entry]
    if filtered:
        attributes.write_text("\n".join(filtered) + "\n", encoding="utf-8")
    else:
        attributes.unlink()
    log(f"Removed merge driver entry from {(attributes.relative_to(ctx.repo_root))}.")


def cleanup_merge_driver_config(ctx: GitContext) -> None:
    owner_marker = f"merge.{MERGE_DRIVER_NAME}.owned"
    name_backup = ctx.state_path(f"merge.{MERGE_DRIVER_NAME}.name.backup")
    driver_backup = ctx.state_path(f"merge.{MERGE_DRIVER_NAME}.driver.backup")

    if (
        not name_backup.exists()
        and not driver_backup.exists()
        and not ctx.state_path(owner_marker).exists()
    ):
        return

    restored = False
    if restore_config_key(ctx, f"merge.{MERGE_DRIVER_NAME}.name", name_backup):
        restored = True
    if restore_config_key(ctx, f"merge.{MERGE_DRIVER_NAME}.driver", driver_backup):
        restored = True

    if ctx.state_path(owner_marker).exists():
        ctx.state_path(owner_marker).unlink()

    if restored:
        log("Restored merge driver configuration from backup.")


def restore_config_key(ctx: GitContext, key: str, backup_file: Path) -> bool:
    subprocess.run(
        ["git", "config", "--local", "--unset-all", key],
        cwd=ctx.repo_root,
        check=False,
    )
    subprocess.run(
        ["git", "config", "--local", "--unset", key],
        cwd=ctx.repo_root,
        check=False,
    )

    if not backup_file.exists():
        return False

    restored_any = False
    with backup_file.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            subprocess.run(
                ["git", "config", "--local", "--add", key, line],
                cwd=ctx.repo_root,
                check=False,
            )
            restored_any = True
    backup_file.unlink()
    return restored_any


def cleanup_aliases(ctx: GitContext) -> None:
    backup_file = ctx.state_path("alias.rebuild-agents.backup")
    owner_marker = ctx.state_path("alias.rebuild-agents.owned")

    if not backup_file.exists() and not owner_marker.exists():
        return

    if backup_file.exists():
        value = backup_file.read_text(encoding="utf-8").strip()
        backup_file.unlink()
        subprocess.run(
            ["git", "config", "--local", "--unset-all", "alias.rebuild-agents"],
            cwd=ctx.repo_root,
            check=False,
        )
        subprocess.run(
            ["git", "config", "--local", "--unset", "alias.rebuild-agents"],
            cwd=ctx.repo_root,
            check=False,
        )
        if value:
            subprocess.run(
                ["git", "config", "--local", "alias.rebuild-agents", value],
                cwd=ctx.repo_root,
                check=False,
            )
        log("Restored alias.rebuild-agents from backup.")
    else:
        subprocess.run(
            ["git", "config", "--local", "--unset-all", "alias.rebuild-agents"],
            cwd=ctx.repo_root,
            check=False,
        )
        subprocess.run(
            ["git", "config", "--local", "--unset", "alias.rebuild-agents"],
            cwd=ctx.repo_root,
            check=False,
        )

    if owner_marker.exists():
        owner_marker.unlink()


def cleanup_index_flags(ctx: GitContext) -> None:
    if git_ls_files(ctx, ctx.agents_md_file):
        subprocess.run(
            ["git", "update-index", "--no-assume-unchanged", ctx.agents_md_file],
            cwd=ctx.repo_root,
            check=False,
        )


def restore_canonical_agents_md(ctx: GitContext) -> None:
    head_exists = subprocess.run(
        ["git", "rev-parse", "-q", "--verify", "HEAD"],
        cwd=ctx.repo_root,
        capture_output=True,
        text=True,
    ).returncode == 0
    if not head_exists:
        return

    cat_file = subprocess.run(
        ["git", "cat-file", "-e", f"HEAD:{ctx.agents_md_file}"],
        cwd=ctx.repo_root,
        capture_output=True,
        text=True,
    )
    if cat_file.returncode != 0:
        return

    show = subprocess.run(
        ["git", "show", f"HEAD:{ctx.agents_md_file}"],
        cwd=ctx.repo_root,
        capture_output=True,
        text=True,
    )
    if show.returncode != 0:
        return
    (ctx.repo_root / ctx.agents_md_file).write_text(show.stdout, encoding="utf-8")
    log(f"Restored {ctx.agents_md_file} to canonical tracked state.")


def remove_state_dir(ctx: GitContext) -> None:
    if not ctx.state_dir.exists():
        return
    try:
        ctx.state_dir.rmdir()
    except OSError:
        pass
