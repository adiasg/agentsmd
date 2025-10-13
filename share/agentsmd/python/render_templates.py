#!/usr/bin/env python3
import os
import re
import sys


def resolve_template(name: str, home_dir: str | None) -> str | None:
    if not home_dir:
        return None
    templates_dir = os.path.join(home_dir, '.agentsmd', 'templates')
    candidates = [
        os.path.join(templates_dir, name),
        os.path.join(templates_dir, f"{name}.md"),
    ]
    for path in candidates:
        if os.path.isfile(path):
            with open(path, 'r', encoding='utf-8') as tmpl:
                return tmpl.read()
    return None


def render(content: str, home_dir: str | None) -> tuple[str, list[str]]:
    pattern = re.compile(r"{{\s*([A-Za-z0-9._-]+)\s*}}")
    cache: dict[str, str | None] = {}
    warnings: list[str] = []

    def substitute(match: re.Match[str]) -> str:
        name = match.group(1)
        if name not in cache:
            cache[name] = resolve_template(name, home_dir)
        resolved = cache[name]
        if resolved is None:
            warnings.append(f"missing {name}")
            return match.group(0)
        # If resolved ends with a newline and is followed by a newline in source, drop one
        # to avoid creating double-blank lines.
        start, end = match.span()
        if resolved.endswith("\n") and end < len(content) and content[end:end+1] == "\n":
            return resolved[:-1]
        return resolved

    return pattern.sub(substitute, content), warnings


def main() -> int:
    if len(sys.argv) < 5:
        return 1
    source, dest, repo_root, home_dir = sys.argv[1:5]
    try:
        with open(source, 'r', encoding='utf-8') as handle:
            content = handle.read()
        rendered, warnings = render(content, home_dir)
        with open(dest, 'w', encoding='utf-8') as handle:
            handle.write(rendered)
        # Print de-duplicated warnings one per line to stdout, like existing behavior
        seen = set()
        for message in warnings:
            if message not in seen:
                print(message)
                seen.add(message)
        return 0
    except Exception:
        return 1


if __name__ == '__main__':
    raise SystemExit(main())


