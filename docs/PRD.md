# Product Requirements: `agentsmd` Instructions for Coding Agents

## Background & Objectives
- `agentsmd` manages a repository's coding agent instructions. This is done through the `AGENTS.md` file at the repository's root.
- `agentsmd` keeps a repository’s `AGENTS.md` accurate without polluting commits. The CLI installs Git-local automation, regenerates the file from developer preferences, and offers diagnostics so contributors can trust the tooling.
- Automation must remain developer-local: only `.git` internals change, while tracked `AGENTS.md` files stay untouched unless a developer deliberately publishes.
- The `agentsmd` commands we want to support:
    - setup (`enable`)
    - teardown (`disable`)
    - diagnostics (`status`)
    - regeneration (`make`)

---

## Command Surface & Functional Requirements

### `agentsmd enable`
- Setup the Git-local automation for management of the `AGENTS.md` file, specifically:
    - Support the generation of `AGENTS.md` file with templates & preferences as defined in `agentsmd make`.
    - Ignore changes to the local `AGENTS.md` file.
    - On changes to the tracked `AGENTS.md` base file (pulls/merges/checkouts etc.) regenerate the file as defined in `agentsmd make`.
    - Backup any conflicting existing Git configuration before overwriting it, and support restoration with `agentsmd disable`.
- Idempotent: repeated runs refresh assets without duplication and respect previous backups.

### `agentsmd disable`
- Removes all automation introduced by `enable` and restores the original state of the Git configuration.
- Restore `AGENTS.md` to the canonical tracked state.
- Safe when run without prior `agentsmd enable`.

### `agentsmd status`
- Evaluates the state of the Git-local automation that `agentsmd enable` sets up.
- When enabled, prints a succint message `Status: ENABLED`.
- When disabled entirely or a configuration component is missing `Status: DISABLED` and lists missing/mismatched components.

### Global Options
- `-h`, `--help`: Show top-level usage, including global options and available commands.
- `--version`: Print the CLI's version.

### `agentsmd make`
- Generates the `AGENTS.md` file at the repository root with templates & preferences (detailed below).
- Every file generation starts from the canonical `AGENTS.md` file at the Git HEAD of the repository.
- Idempotent & deterministic: regeneration results in the same deterministic output.

#### Preferences
- Read developer preferences from `.agentsmd` at the repository root, and append to the base `AGENTS.md` file:
  - Missing `.agentsmd` file: warn once and skip append.
  - Empty or whitespace-only file: log notice, no append.
  - Non-empty file: append content and ensure:
    - a single blank line between existing content and the appended content.
    - a trailing newline at the end of the appended content.

#### Templates
- Supports inline template tokens inside the base `AGENTS.md` and `.agentsmd`:
  - Recognise `{{ name }}` patterns and replace them with the contents of the first template file discovered in `~/.agentsmd/templates/<name>`.
  - Attempt to load both `<name>` and `<name>.md`, preferring whichever exists first. This keeps `.md` optional while encouraging Markdown naming for editor tooling.
  - Missing templates emit a warning and leave the token untouched so developers can fix their library without losing context.
  - Template rendering formatting guidelines:
    - If there is prefix content, ensure a single blank line between prefix content and the template content.
    - If there is suffix content, ensure a single blank line between template content and the suffix content. Else, ensure a trailing newline at the end of the template content.

---

## Workflows

### Setup (First-Run)
1. Developer executes `agentsmd enable` from the repo root.
2. CLI installs config and performs an initial `agentsmd make` render.
3. `git status` remains clean because `AGENTS.md` is marked assume-unchanged.

### Day-to-Day
1. Developers edit `.agentsmd` as needed.
2. Run `agentsmd make` to refresh the local file. Automation also re-renders after merges or checkouts.
3. Local edits stay unstaged. `status` can confirm everything is healthy and highlight missing setup pieces.

### Teardown / Troubleshooting
1. Run `agentsmd disable` to restore previous Git setup and revert `AGENTS.md` to canonical tracked state.
2. Re-run `agentsmd enable` to reinstall config at any time.

---

## Edge Cases & Error Handling
- All commands must run only inside a Git repository, fail with `fatal: not a git repository` otherwise.
- `AGENTS.md` not tracked → `status` marks assume-unchanged as missing; `enable` warns when unable to mark the flag.
- HEAD missing or file untracked → `make` falls back to the working-tree file as the base before reapplying preferences.
- Read-only destinations → `make` fails with a clear error before overwriting.

---

## Non-Functional Requirements
- **Portability**: CLI is implemented in Python 3 and should run on macOS and Linux with a system `git`; supporting Git hook helpers remain Bash-compatible.
- **Safety**: Automation never modifies tracked repository files besides the managed `AGENTS.md`; all other changes stay inside `.git`.
- **Testability**: Pytest coverage for enable/disable/status/make flows, idempotency, repository enforcement, and regeneration behaviour.
- **Resilience**: Setup tolerates repeated runs and restores user state during disable, even when names collide with existing hooks or aliases.

---

## Deliverables
1. CLI command implementations under `agentsmd/` (Python modules for `enable`, `disable`, `status`, `make`) wired through `bin/agentsmd`.
2. Git asset scripts and templates under `share/agentsmd/git/`.
3. Automated tests (`tests/*.py`) covering product requirements via pytest.
4. README highlights the core value proposition and stays in sync with the supported command surface.
