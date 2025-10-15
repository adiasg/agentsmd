from __future__ import annotations

import contextlib
import io
import os
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import NamedTuple, Optional

import pytest

import agentsmd.cli as agentsmd_cli


class CLIResult(NamedTuple):
    returncode: int
    stdout: str
    stderr: str


@dataclass
class Repo:
    #: Root of the temporary Git repository used in tests.
    path: Path

    #: Checked-out agentsmd project root that hosts the CLI under test.
    project_root: Path

    #: Stateful working directory representing the test user's current location.
    cwd: Path = field(init=False)

    #: Whether ``git init`` has been executed for this repository helper.
    git_initialized: bool = field(default=False, init=False)

    def __post_init__(self) -> None:
        self.path = self.path.resolve()
        self.cwd = self.path

    def run(self, *args: str, check: bool = False) -> CLIResult:
        """Invoke the agentsmd CLI under test with the provided arguments.

        Parameters
        ----------
        *args:
            Command-line arguments forwarded to the CLI entry point.
        check:
            Raise :class:`subprocess.CalledProcessError` if the exit code is
            non-zero when ``True``.

        Returns
        -------
        CLIResult
            Captured ``returncode``, ``stdout``, and ``stderr`` from the
            invocation.
        """
        stdout_buffer = io.StringIO()
        stderr_buffer = io.StringIO()
        returncode: int

        # original_cwd is the working directory of this test process.
        # cache it so we can restore it later
        original_cwd = Path.cwd()
        try:
            # cwd is the stateful working directory of test "user"
            os.chdir(self.cwd)
            with contextlib.redirect_stdout(stdout_buffer), contextlib.redirect_stderr(
                stderr_buffer
            ):
                returncode = agentsmd_cli.main(list(args))
        except SystemExit as exc:
            code = exc.code
            returncode = code if isinstance(code, int) else 1
        finally:
            # restore the original working directory of the test process
            os.chdir(original_cwd)

        result = CLIResult(returncode, stdout_buffer.getvalue(), stderr_buffer.getvalue())
        if check and returncode != 0:
            raise subprocess.CalledProcessError(
                returncode, ["agentsmd", *args], output=result.stdout, stderr=result.stderr
            )
        return result

    def git(self, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        """Execute a Git subprocess scoped to the repo's current working directory.

        Parameters
        ----------
        *args:
            Git command arguments, e.g., ``("status",)`` or ``("config", "--list")``.
        check:
            When ``True``, propagate non-zero exit codes as
            :class:`subprocess.CalledProcessError`.

        Returns
        -------
        subprocess.CompletedProcess[str]
            Completed process with captured ``stdout``/``stderr`` text.
        """
        return subprocess.run(
            ["git", *args],
            cwd=self.cwd,
            capture_output=True,
            text=True,
            check=check,
        )

    def cd(self, path: str | Path) -> Path:
        """Change the repo's stateful working directory to a path within the repo."""
        target = (self.path / Path(path)).resolve(strict=False)

        try:
            target.relative_to(self.path)
        except ValueError as exc:  # pragma: no cover - defensive guard
            raise ValueError(f"Path {target} is outside repository {self.path}") from exc

        target.mkdir(parents=True, exist_ok=True)
        self.cwd = target
        return self.cwd

    def write(self, path: str, content: str) -> Path:
        """Write text content to a file relative to the repository root."""
        target = self.path / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return target

    def read(self, path: str) -> str:
        """Read and return text content from a file relative to the repository root."""
        return (self.path / path).read_text(encoding="utf-8")

    # --- Git helpers -----------------------------------------------------

    def init_git(self) -> None:
        """Initialise the repository as a Git repo with default user config."""
        if self.git_initialized:
            return

        subprocess.run(["git", "init", "-q"], cwd=self.path, check=True)
        subprocess.run(["git", "config", "user.name", "Test User"], cwd=self.path, check=True)
        subprocess.run(
            ["git", "config", "user.email", "test@example.com"], cwd=self.path, check=True
        )
        self.git_initialized = True


@pytest.fixture
def project_root() -> Path:
    """Absolute path to the checked-out agentsmd project under test."""
    return Path(__file__).resolve().parents[1]


@pytest.fixture
def repo(
    tmp_path: Path,
    project_root: Path,
    monkeypatch: pytest.MonkeyPatch,
    request: pytest.FixtureRequest,
) -> Repo:
    """Provision a repository helper, optionally skipping git init via mark."""

    repo_dir = tmp_path / "repo"
    repo_dir.mkdir()

    home = repo_dir / "home"
    home.mkdir()
    monkeypatch.setenv("HOME", str(home))

    helper = Repo(path=repo_dir, project_root=project_root)

    mark: Optional[pytest.Mark] = request.node.get_closest_marker("git_initialized")
    if mark is None:
        should_init_git = True
    elif mark.args:
        should_init_git = bool(mark.args[0])
    else:
        should_init_git = bool(mark.kwargs.get("value", True))

    if should_init_git:
        helper.init_git()

    return helper
