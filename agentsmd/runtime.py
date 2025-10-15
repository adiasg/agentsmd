"""Shared runtime helpers for the agentsmd CLI."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Iterable, NoReturn

from . import PROJECT_ROOT

SHARE_DIR = PROJECT_ROOT / "share" / "agentsmd"

QUIET = os.environ.get("AGENTSMD_QUIET", "0") == "1"


class AgentsMDError(RuntimeError):
    """Custom error for CLI failures."""


def log(message: str, *, error: bool = False) -> None:
    """Emit a structured log message to stderr."""
    if QUIET and not error:
        return
    stream = sys.stderr
    stream.write(f"[agentsmd] {message}\n")


def die(message: str) -> NoReturn:
    """Raise a CLI failure that will be rendered uniformly."""
    raise AgentsMDError(message)


def ensure_repo_root() -> Path:
    """Return the repository root according to git, or die if not in a repo."""
    try:
        output = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError:
        die("fatal: not a git repository")

    return Path(output.stdout.strip())


def run_git(
    args: Iterable[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    capture_output: bool = False,
    text: bool = True,
) -> subprocess.CompletedProcess[str]:
    """Execute a git command."""
    command = ["git", *args]
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            check=check,
            capture_output=capture_output,
            text=text,
        )
    except subprocess.CalledProcessError as exc:
        raise AgentsMDError(f"git command failed: {' '.join(command)}") from exc


def read_file(path: Path, *, missing_ok: bool = False) -> str:
    """Read a UTF-8 file and return its contents."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        if missing_ok:
            return ""
        raise


def write_file(path: Path, data: str) -> None:
    """Write UTF-8 data to a file, creating parent directories as needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data, encoding="utf-8")
