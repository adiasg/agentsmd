"""Shared helpers for interacting with the repository's Git metadata."""

from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

from .runtime import die


@dataclass
class GitContext:
    repo_root: Path
    git_dir: Path
    hooks_dir: Path
    info_dir: Path
    attributes_file: Path
    state_dir: Path
    agents_md_file: str

    def state_path(self, name: str) -> Path:
        return self.state_dir / name


def build_git_context(repo_root: Path) -> GitContext:
    git_dir_output = subprocess.run(
        ["git", "rev-parse", "--git-dir"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if git_dir_output.returncode != 0:
        die("fatal: not a git repository")
    git_dir = Path(git_dir_output.stdout.strip())
    if not git_dir.is_absolute():
        git_dir = repo_root / git_dir

    hooks_dir = git_dir / "hooks"
    info_dir = git_dir / "info"
    attributes_file = info_dir / "attributes"
    state_dir = git_dir / "agentsmd-state"

    agents_md_file = os.environ.get("AGENTS_MD_FILE", "AGENTS.md")
    return GitContext(
        repo_root=repo_root,
        git_dir=git_dir,
        hooks_dir=hooks_dir,
        info_dir=info_dir,
        attributes_file=attributes_file,
        state_dir=state_dir,
        agents_md_file=agents_md_file,
    )


def ensure_state_dir(ctx: GitContext) -> None:
    ctx.state_dir.mkdir(parents=True, exist_ok=True)


def mark_owned(ctx: GitContext, name: str) -> None:
    ensure_state_dir(ctx)
    ctx.state_path(name).write_text("owned\n", encoding="utf-8")


def is_owned(ctx: GitContext, name: str) -> bool:
    return ctx.state_path(name).exists()


def read_git_config(ctx: GitContext, key: str) -> str | None:
    result = subprocess.run(
        ["git", "config", "--local", "--get", key],
        cwd=ctx.repo_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def read_git_config_all(ctx: GitContext, key: str) -> list[str]:
    result = subprocess.run(
        ["git", "config", "--local", "--get-all", key],
        cwd=ctx.repo_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line]


def git_ls_files(ctx: GitContext, path: str) -> bool:
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", path],
        cwd=ctx.repo_root,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def is_managed_hook(path: Path) -> bool:
    """Return True if the hook file is managed by agentsmd."""
    if not path.exists():
        return False
    try:
        contents = path.read_text(encoding="utf-8")
    except OSError:
        return False
    return "# AGENTS_MD_MANAGEMENT" in contents
