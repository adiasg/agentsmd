# Introduction

This repository contains a CLI tool for [`AGENTS.md`](https://agents.md) file management.  
Additional context is provided in the [README](README.md) and the [PRD](docs/PRD.md). When making changes, make sure to update the README and PRD.

## Project Structure

- `bin/` – executable entrypoints distributed via npm (`agentsmd`).
- `lib/agentsmd/` – shared shell libraries and subcommand registrations.
- `share/agentsmd/` – packaged assets (Git hook templates, helper scripts).
- `docs/` – product specs and long-form documentation.
- `scripts/` – contributor utilities (`lint`, `test`, release helpers).
- `tests/` – shell-based test suites.
