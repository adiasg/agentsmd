"""CLI entrypoint for agentsmd."""

from __future__ import annotations

import os
import sys
from typing import Sequence

from . import PROJECT_ROOT, get_version
from .commands import get_command, iter_commands
from .runtime import AgentsMDError, SHARE_DIR, log


USAGE_HEADER = "Usage: agentsmd <command> [options]\n"


def print_usage() -> None:
    print(USAGE_HEADER)
    print("Global options:")
    print("  -h, --help     Show this help message")
    print("  --version      Show CLI version")
    print("\nCommands:")
    for command in iter_commands():
        print(f"  {command.name:<20} {command.summary}")
    print("\nUse `agentsmd help <command>` to view command-specific help.")


def main(argv: Sequence[str] | None = None) -> int:
    args = list(argv if argv is not None else sys.argv[1:])

    os.environ.setdefault("AGENTSMD_ROOT", str(PROJECT_ROOT))
    os.environ.setdefault("AGENTSMD_SHARE_DIR", str(SHARE_DIR))

    if not args:
        print_usage()
        return 0

    head = args[0]

    if head in {"-h", "--help"}:
        print_usage()
        return 0

    if head == "--version":
        print(get_version())
        return 0

    if head == "help":
        if len(args) == 1:
            print_usage()
            return 0
        command = get_command(args[1])
        if command is None:
            log(f"ERROR: Unknown command '{args[1]}'", error=True)
            return 1
        return command.handler(["--help"]) or 0

    command = get_command(head)
    if command is None:
        log(f"ERROR: Unknown command '{head}'", error=True)
        return 1

    try:
        return command.handler(args[1:]) or 0
    except AgentsMDError as exc:
        log(f"ERROR: {exc}", error=True)
        return 1
    except KeyboardInterrupt:
        log("ERROR: interrupted", error=True)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
