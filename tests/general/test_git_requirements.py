from __future__ import annotations

import pytest

from conftest import Repo


@pytest.mark.parametrize("command", ["enable", "make", "disable", "status"])
@pytest.mark.git_initialized(False)
def test_commands_require_git_repository(repo: Repo, command: str) -> None:
    result = repo.run(command)

    assert result.returncode != 0
    assert "fatal: not a git repository" in result.stderr
