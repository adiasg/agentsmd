from __future__ import annotations

import io
from contextlib import redirect_stdout

import agentsmd.cli as agentsmd_cli


def _invoke_help(args: list[str]) -> str:
    buffer = io.StringIO()
    exit_code: int
    with redirect_stdout(buffer):
        exit_code = agentsmd_cli.main(args)
    assert exit_code == 0
    return buffer.getvalue()


def test_global_help_short_option() -> None:
    output = _invoke_help(["-h"])
    assert "Usage: agentsmd" in output
    assert "Global options:" in output
    assert "Commands:" in output


def test_global_help_long_option() -> None:
    output = _invoke_help(["--help"])
    assert "Usage: agentsmd" in output
    assert "Global options:" in output
    assert "Commands:" in output
