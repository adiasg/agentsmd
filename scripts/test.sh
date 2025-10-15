#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

PYTHON_BIN=${PYTHON_BIN:-python3}
if ! command -v "$PYTHON_BIN" > /dev/null 2>&1; then
  if command -v python > /dev/null 2>&1; then
    PYTHON_BIN=python
  else
    echo "[test] python interpreter not found; cannot run tests." >&2
    exit 1
  fi
fi

if "$PYTHON_BIN" -m pytest --version > /dev/null 2>&1; then
  if "$PYTHON_BIN" -m pytest --help 2> /dev/null | grep -q -- '--cov='; then
    "$PYTHON_BIN" -m pytest \
      --cov=agentsmd \
      --cov-report=term-missing \
      --cov-report=xml \
      --cov-report=html "$@"
  else
    echo "[test] pytest-cov not installed; collecting coverage with trace module." >&2
    COVERAGE_TRACE_DIR=${COVERAGE_TRACE_DIR:-coverage-trace}
    rm -rf "$COVERAGE_TRACE_DIR"

    set +e
    "$PYTHON_BIN" - "$COVERAGE_TRACE_DIR" "$ROOT_DIR" "$@" <<'PYCODE'
import site
import sys
import trace
from pathlib import Path

import pytest


def main(argv: list[str]) -> int:
    coverdir = Path(argv[1])
    root = Path(argv[2])
    pytest_args = argv[3:]

    ignoredirs: set[str] = {str((root / "tests").resolve())}
    ignoremods = {"pytest", "_pytest"}

    getsitepackages = getattr(site, "getsitepackages", lambda: [])
    for path in getsitepackages() or []:
        if path:
            ignoredirs.add(str(Path(path).resolve()))

    usersite = getattr(site, "getusersitepackages", lambda: "")()
    if isinstance(usersite, str) and usersite:
        ignoredirs.add(str(Path(usersite).resolve()))

    for prefix in (sys.prefix, sys.base_prefix):
        if prefix:
            ignoredirs.add(str(Path(prefix).resolve()))

    coverdir.mkdir(parents=True, exist_ok=True)

    tracer = trace.Trace(
        count=True,
        trace=False,
        ignoremods=tuple(ignoremods),
        ignoredirs=tuple(ignoredirs),
    )

    exit_code = tracer.runfunc(pytest.main, pytest_args)
    results = tracer.results()
    results.write_results(show_missing=True, summary=True, coverdir=str(coverdir))
    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PYCODE
    TEST_STATUS=$?
    set -e

    exit "$TEST_STATUS"
  fi
else
  echo "[test] pytest not installed; skipping tests." >&2
fi
