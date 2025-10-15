from __future__ import annotations

import hashlib
from pathlib import Path

from conftest import Repo


def hash_file(path: Path) -> str:
    """Return the SHA-1 hex digest of a file's contents."""
    return hashlib.sha1(path.read_bytes()).hexdigest()


def working_tree_hash(repo_path: Path) -> str:
    """Hash all non-git files in the working tree for idempotency checks."""
    digest = hashlib.sha1()
    for file in sorted(repo_path.rglob("*")):
        if file.is_dir() or ".git" in file.parts:
            continue
        digest.update(str(file.relative_to(repo_path)).encode("utf-8"))
        digest.update(file.read_bytes())
    return digest.hexdigest()


def git_state_hash(repo_path: Path) -> str:
    """Hash the Git directory contents for state comparisons."""
    git_dir = repo_path / ".git"
    digest = hashlib.sha1()
    if not git_dir.exists():
        return digest.hexdigest()
    for file in sorted(git_dir.rglob("*")):
        if file.is_dir():
            continue
        digest.update(str(file.relative_to(git_dir)).encode("utf-8"))
        digest.update(file.read_bytes())
    return digest.hexdigest()


def git_config_semantic_hash(repo: Repo) -> str:
    """Hash Git config entries to detect semantic changes."""
    listing = repo.git("config", "--local", "--list")
    lines = sorted(filter(None, listing.stdout.splitlines()))
    digest = hashlib.sha1()
    for line in lines:
        digest.update(line.encode("utf-8"))
    return digest.hexdigest()
