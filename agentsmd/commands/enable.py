"""Implementation of the `agentsmd enable` command."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

from .. import PROJECT_ROOT
from ..git_tools import (
    GitContext,
    build_git_context,
    ensure_state_dir,
    git_ls_files,
    is_managed_hook,
    is_owned,
    mark_owned,
    read_git_config,
    read_git_config_all,
)
from ..runtime import SHARE_DIR, die, ensure_repo_root, log, run_git

HELP_TEXT = """Usage: agentsmd enable [options]

Installs Git hooks, merge drivers, and aliases that keep AGENTS.md managed by
agentsmd.

Options:
  -h, --help    Show this help message.
"""

SUMMARY = "Install Git automation for AGENTS.md"

MERGE_DRIVER_NAME = "agentsmd"


def run(argv: list[str]) -> int:
    if argv and argv[0] in {"-h", "--help"}:
        print(HELP_TEXT, end="")
        return 0
    if argv:
        die(f"Unknown option for enable command: {' '.join(argv)}")

    repo_root = ensure_repo_root()
    ctx = build_git_context(repo_root)

    hooks_template_dir = SHARE_DIR / "git" / "templates" / "hooks"

    install_common_assets(ctx, hooks_template_dir)
    install_hook(ctx, hooks_template_dir, "pre-commit", "pre-commit.sh")
    install_hook(ctx, hooks_template_dir, "post-merge", "post-merge.sh")
    install_hook(ctx, hooks_template_dir, "post-checkout", "post-checkout.sh")
    ensure_attributes(ctx)
    configure_merge_driver(ctx)
    configure_aliases(ctx)
    mark_assume_unchanged(ctx)
    initial_render(ctx)

    log("Setup complete. Use:")
    log("\t- 'agentsmd make' to regenerate AGENTS.md")
    log("\t- 'agentsmd status' to check status.")
    log("\t- 'agentsmd disable' to uninstall setup.")
    return 0


def install_common_assets(ctx: GitContext, template_dir: Path) -> None:
    common_source = template_dir / "agentsmd-hooks-common.sh"
    merge_driver_source = template_dir / "agentsmd-merge-driver.sh"

    write_template(common_source, ctx.hooks_dir / "agentsmd-hooks-common.sh", 0o755)
    write_template(merge_driver_source, ctx.hooks_dir / "agentsmd-merge-driver.sh", 0o755)


def write_template(source: Path, destination: Path, mode: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    try:
        os.chmod(destination, mode)
    except OSError:
        pass


def install_hook(ctx: GitContext, template_dir: Path, hook_name: str, template_file: str) -> None:
    hook_path = ctx.hooks_dir / hook_name
    backup_path = hook_path.with_suffix(".agentsmd.bak")

    backup_existing_hook_if_needed(hook_path, backup_path)
    write_template(template_dir / template_file, hook_path, 0o755)

    if backup_path.exists():
        with hook_path.open("a", encoding="utf-8") as handle:
            handle.write("\n")
            handle.write("# AGENTS_MD_MANAGEMENT: previous hook preserved at:\n")
            handle.write(f"#   {backup_path}\n")


def backup_existing_hook_if_needed(hook_path: Path, backup_path: Path) -> None:
    if hook_path.exists() and not is_managed_hook(hook_path):
        if not backup_path.exists():
            hook_path.rename(backup_path)
            log(f"Existing {hook_path.name} hook moved to {backup_path.name}.")
        else:
            log(
                f"NOTICE: Existing {hook_path.name} hook already backed up at {backup_path.name}."
            )


def ensure_attributes(ctx: GitContext) -> None:
    ctx.info_dir.mkdir(parents=True, exist_ok=True)
    if not ctx.attributes_file.exists():
        ctx.attributes_file.write_text("", encoding="utf-8")

    entry = f"{ctx.agents_md_file} merge={MERGE_DRIVER_NAME}"
    existing = ctx.attributes_file.read_text(encoding="utf-8").splitlines()
    if entry not in existing:
        with ctx.attributes_file.open("a", encoding="utf-8") as handle:
            handle.write(entry + "\n")
        relative = ctx.attributes_file.relative_to(ctx.repo_root)
        log(f"Added {ctx.agents_md_file} merge driver to {relative}.")


def configure_merge_driver(ctx: GitContext) -> None:
    backup_merge_config_if_needed(ctx)

    run_git(
        ["config", "--local", f"merge.{MERGE_DRIVER_NAME}.name", f"Prefer remote {ctx.agents_md_file}"],
        cwd=ctx.repo_root,
    )
    run_git(
        [
            "config",
            "--local",
            f"merge.{MERGE_DRIVER_NAME}.driver",
            f"{ctx.hooks_dir / 'agentsmd-merge-driver.sh'} %O %A %B",
        ],
        cwd=ctx.repo_root,
    )
    mark_owned(ctx, f"merge.{MERGE_DRIVER_NAME}.owned")


def configure_aliases(ctx: GitContext) -> None:
    cli_cmd = os.environ.get("AGENTS_CLI_CMD")
    if not cli_cmd:
        cli_cmd = str(PROJECT_ROOT / "bin" / "agentsmd")
    cli_args = os.environ.get("AGENTS_CLI_ARGS", "make").strip()

    alias_command = f"!{cli_cmd}"
    if cli_args:
        alias_command = f"{alias_command} {cli_args}"

    backup_alias_if_needed(ctx, alias_command)
    run_git(
        ["config", "--local", "alias.rebuild-agents", alias_command],
        cwd=ctx.repo_root,
    )
    mark_owned(ctx, "alias.rebuild-agents.owned")


def mark_assume_unchanged(ctx: GitContext) -> None:
    if git_ls_files(ctx, ctx.agents_md_file):
        try:
            result = subprocess.run(
                ["git", "update-index", "--assume-unchanged", ctx.agents_md_file],
                cwd=ctx.repo_root,
                check=False,
                capture_output=True,
            )
        except OSError:
            log(f"WARNING: Unable to mark {ctx.agents_md_file} assume-unchanged.")
            return
        if result.returncode != 0:
            log(f"WARNING: Unable to mark {ctx.agents_md_file} assume-unchanged.")
    else:
        log(f"WARNING: {ctx.agents_md_file} is not tracked; skipping assume-unchanged.")


def initial_render(ctx: GitContext) -> None:
    cli_cmd = os.environ.get("AGENTS_CLI_CMD")
    if not cli_cmd:
        cli_cmd = str(PROJECT_ROOT / "bin" / "agentsmd")
    cli_args = os.environ.get("AGENTS_CLI_ARGS", "make").strip().split()

    executable = Path(cli_cmd)
    if not executable.is_file() or not os.access(executable, os.X_OK):
        resolved = shutil.which(cli_cmd)
        if resolved:
            cli_cmd = resolved
        else:
            log(f"NOTICE: Skipping initial render; '{os.environ.get('AGENTS_CLI_CMD', cli_cmd)}' is not executable.")
            return

    try:
        subprocess.run([cli_cmd, *cli_args], cwd=ctx.repo_root, check=True)
    except subprocess.CalledProcessError:
        log(f"WARNING: Initial render via {cli_cmd} {' '.join(cli_args)} failed")


def backup_alias_if_needed(ctx: GitContext, alias_command: str) -> None:
    alias_key = "alias.rebuild-agents"
    owner_marker = "alias.rebuild-agents.owned"
    backup_file = ctx.state_path("alias.rebuild-agents.backup")

    if is_owned(ctx, owner_marker):
        if backup_file.exists():
            backup_file.unlink()
        return

    existing = read_git_config(ctx, alias_key)
    if existing is not None:
        ensure_state_dir(ctx)
        backup_file.write_text(existing + "\n", encoding="utf-8")
    elif backup_file.exists():
        backup_file.unlink()


def backup_merge_config_if_needed(ctx: GitContext) -> None:
    owner_marker = f"merge.{MERGE_DRIVER_NAME}.owned"
    name_backup = ctx.state_path(f"merge.{MERGE_DRIVER_NAME}.name.backup")
    driver_backup = ctx.state_path(f"merge.{MERGE_DRIVER_NAME}.driver.backup")

    if is_owned(ctx, owner_marker):
        for path in (name_backup, driver_backup):
            if path.exists():
                path.unlink()
        return

    name_key = f"merge.{MERGE_DRIVER_NAME}.name"
    driver_key = f"merge.{MERGE_DRIVER_NAME}.driver"

    existing_name = read_git_config_all(ctx, name_key)
    existing_driver = read_git_config_all(ctx, driver_key)

    ensure_state_dir(ctx)
    if existing_name:
        name_backup.write_text("\n".join(existing_name) + "\n", encoding="utf-8")
    elif name_backup.exists():
        name_backup.unlink()

    if existing_driver:
        driver_backup.write_text("\n".join(existing_driver) + "\n", encoding="utf-8")
    elif driver_backup.exists():
        driver_backup.unlink()
