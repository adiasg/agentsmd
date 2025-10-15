from __future__ import annotations

import io
import json
from contextlib import redirect_stdout
from pathlib import Path

import agentsmd.cli as agentsmd_cli


def test_version_matches_package_json(project_root: Path) -> None:
    package_json = json.loads((project_root / "package.json").read_text(encoding="utf-8"))
    expected = package_json["version"]

    buffer = io.StringIO()
    with redirect_stdout(buffer):
        exit_code = agentsmd_cli.main(["--version"])

    assert exit_code == 0
    assert buffer.getvalue().strip() == expected
