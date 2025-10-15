from __future__ import annotations

from conftest import Repo
from tests.helpers.hash_utils import (
    git_config_semantic_hash,
    git_state_hash,
    working_tree_hash,
)


def test_enable_installs_hooks_and_alias(repo: Repo) -> None:
    repo.write("AGENTS.md", "")
    repo.git("add", "AGENTS.md")

    result = repo.run("enable")

    assert result.returncode == 0

    pre_commit = repo.path / ".git/hooks/pre-commit"
    assert pre_commit.exists()
    assert "AGENTS_MD_MANAGEMENT" in pre_commit.read_text(encoding="utf-8")

    alias = repo.git("config", "--local", "--get", "alias.rebuild-agents", check=True)
    expected_alias = f"!{(repo.project_root / 'bin' / 'agentsmd').resolve()} make"
    assert alias.stdout.strip() == expected_alias

    attributes = repo.path / ".git/info/attributes"
    assert attributes.exists()
    assert "AGENTS.md merge=agentsmd" in attributes.read_text(encoding="utf-8")


def test_disable_removes_automation(repo: Repo) -> None:
    repo.write("AGENTS.md", "")
    repo.git("add", "AGENTS.md")
    repo.run("enable")

    result = repo.run("disable")

    assert result.returncode == 0
    assert not (repo.path / ".git/hooks/pre-commit").exists()

    alias = repo.git("config", "--local", "--get", "alias.rebuild-agents", check=False)
    assert alias.returncode != 0

    attributes = repo.path / ".git/info/attributes"
    if attributes.exists():
        assert "AGENTS.md merge=agentsmd" not in attributes.read_text(encoding="utf-8")


def test_enable_is_idempotent(repo: Repo) -> None:
    repo.write("AGENTS.md", "Base instructions\n")
    repo.git("add", "AGENTS.md")

    first = repo.run("enable")
    assert first.returncode == 0
    src_first = working_tree_hash(repo.path)
    git_first = git_state_hash(repo.path)

    second = repo.run("enable")
    assert second.returncode == 0
    src_second = working_tree_hash(repo.path)
    git_second = git_state_hash(repo.path)

    assert src_first == src_second
    assert git_first == git_second


def test_disable_is_idempotent(repo: Repo) -> None:
    repo.write("AGENTS.md", "Base instructions\n")
    repo.git("add", "AGENTS.md")
    repo.run("enable")

    first = repo.run("disable")
    assert first.returncode == 0
    src_first = working_tree_hash(repo.path)
    git_first = git_state_hash(repo.path)

    second = repo.run("disable")
    assert second.returncode == 0
    src_second = working_tree_hash(repo.path)
    git_second = git_state_hash(repo.path)

    assert src_first == src_second
    assert git_first == git_second


def test_enable_disable_restores_user_state(repo: Repo) -> None:
    hooks_dir = repo.path / ".git/hooks"
    hooks_dir.mkdir(parents=True, exist_ok=True)
    pre_commit = hooks_dir / "pre-commit"
    pre_commit.write_text("#!/usr/bin/env bash\necho original-user-hook\n", encoding="utf-8")
    pre_commit.chmod(0o755)

    repo.git("config", "--local", "alias.rebuild-agents", "!echo from-user")
    repo.git("config", "--local", "merge.agentsmd.name", "User Provided Name")
    repo.git("config", "--local", "merge.agentsmd.driver", "echo custom-driver %O %A %B")

    repo.write("AGENTS.md", "Base instructions\n")
    repo.git("add", "AGENTS.md")
    repo.git("commit", "-m", "seed AGENTS", check=True)

    src_before = working_tree_hash(repo.path)
    # We use the hash of the semantic Git config because the .git/config file does not retain the same ordering after disable.
    config_before = git_config_semantic_hash(repo)

    repo.run("enable")
    repo.run("disable")

    src_after = working_tree_hash(repo.path)
    config_after = git_config_semantic_hash(repo)

    assert src_before == src_after
    assert config_before == config_after


def test_disable_without_enable_preserves_state(repo: Repo) -> None:
    src_before = working_tree_hash(repo.path)
    git_before = git_state_hash(repo.path)

    result = repo.run("disable")

    assert result.returncode == 0
    assert working_tree_hash(repo.path) == src_before
    assert git_state_hash(repo.path) == git_before


def test_disable_restores_agents_md_to_canonical_state(repo: Repo) -> None:
    repo.write("AGENTS.md", "Base instructions\n")
    repo.git("add", "AGENTS.md")
    repo.git("commit", "-m", "base snapshot")

    repo.write(".agentsmd", "preferences content\n")

    repo.run("enable")
    repo.run("disable")

    assert repo.read("AGENTS.md") == "Base instructions\n"


def test_enable_masks_agents_md_from_status(repo: Repo) -> None:
    repo.write("AGENTS.md", "Base instructions\n")
    repo.git("add", "AGENTS.md")
    repo.git("commit", "-m", "seed AGENTS snapshot", check=True)

    result = repo.run("enable")
    assert result.returncode == 0

    repo.write("AGENTS.md", "Base instructions\nlocal changes\n")

    status = repo.git("status", "--short", check=True)
    assert "AGENTS.md" not in status.stdout
