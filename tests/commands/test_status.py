from __future__ import annotations

from conftest import Repo


def test_status_reports_disabled_by_default(repo: Repo) -> None:
    result = repo.run("status")

    assert result.returncode == 0
    assert "Status: DISABLED" in result.stderr


def test_status_reports_enabled_after_install(repo: Repo) -> None:
    repo.write(".agentsmd", "prefers tabs\n")
    repo.write("AGENTS.md", "Base instructions\n")
    repo.git("add", "AGENTS.md")
    repo.git("commit", "-m", "seed AGENTS")

    enable_result = repo.run("enable")
    assert enable_result.returncode == 0

    status = repo.run("status")
    assert status.returncode == 0
    assert "Status: ENABLED" in status.stderr
    prefs_path = (repo.path / ".agentsmd").resolve()
    assert f"Developer preferences: {prefs_path}" in status.stderr


def test_status_reports_disabled_after_disable(repo: Repo) -> None:
    repo.run("enable")
    repo.run("disable")

    status = repo.run("status")
    assert status.returncode == 0
    assert "Status: DISABLED" in status.stderr
