"""Command registration for the agentsmd CLI."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

from . import disable, enable, make, status


Handler = Callable[[list[str]], int]


@dataclass(frozen=True)
class Command:
    name: str
    summary: str
    help_text: str
    handler: Handler


COMMANDS: dict[str, Command] = {
    "make": Command("make", make.SUMMARY, make.HELP_TEXT, make.run),
    "enable": Command("enable", enable.SUMMARY, enable.HELP_TEXT, enable.run),
    "disable": Command("disable", disable.SUMMARY, disable.HELP_TEXT, disable.run),
    "status": Command("status", status.SUMMARY, status.HELP_TEXT, status.run),
}


def get_command(name: str) -> Command | None:
    return COMMANDS.get(name)


def iter_commands() -> list[Command]:
    return sorted(COMMANDS.values(), key=lambda cmd: cmd.name)
