#!/usr/bin/env python3
import os
import sys


def main() -> int:
    if len(sys.argv) < 2:
        return 1
    path = sys.argv[1]

    # No-op if file does not exist
    if not os.path.isfile(path):
        return 0

    try:
        with open(path, 'r', encoding='utf-8') as handle:
            data = handle.read()
        # Remove all trailing newlines, then add exactly one if file is non-empty
        if data:
            data = data.rstrip('\n') + '\n'
        with open(path, 'w', encoding='utf-8', newline='') as handle:
            handle.write(data)
        return 0
    except Exception:
        return 1


if __name__ == '__main__':
    raise SystemExit(main())


