"""agentsmd package entrypoint."""

from __future__ import annotations

from pathlib import Path
import json
import os

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _load_package_version() -> str:
    env_version = os.environ.get("AGENTSMD_VERSION")
    if env_version:
        return env_version

    package_json = PROJECT_ROOT / "package.json"
    try:
        with package_json.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except OSError:
        return "0.0.0-dev"

    return data.get("version", "0.0.0-dev")


__all__ = ["get_version", "PROJECT_ROOT"]


def get_version() -> str:
    """Return the package version string."""
    return _load_package_version()
