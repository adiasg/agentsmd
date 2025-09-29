# Product Requirements: `agentsmd` Local Automation

## Background & Objectives
- `agentsmd` keeps a repository’s `AGENTS.md` accurate without polluting commits. The CLI installs Git-local automation, regenerates the file from developer preferences, and offers diagnostics so contributors can trust the tooling.
- Automation must remain developer-local: only `.git` internals change, while tracked files stay untouched unless a developer deliberately publishes.
- The single PRD below replaces prior split documents and captures requirements for setup (`enable`), teardown (`disable`), diagnostics (`status`), and regeneration (`make`).

---

## Command Surface & Functional Requirements

### `agentsmd enable`
- Must run inside a Git repository; fail with `fatal: not a git repository` otherwise.
- Executes the packaged setup script to install:
  - Merge driver wiring in `.git/info/attributes` plus `merge.agentsmd.*` config pointing to the installed driver.
  - Hooks (`pre-commit`, `post-merge`, `post-checkout`) and shared helper scripts.
  - `git update-index --assume-unchanged` for the managed `AGENTS.md`.
  - `git alias rebuild-agents` pointing at the CLI (`agentsmd make` by default).
- Before overwriting existing hooks/config/aliases, back them up under `.git/agentsmd-state` (`*.backup`) and remember ownership markers so disable can restore them.
- Honour environment overrides (`AGENTS_MD_FILE`, `AGENTS_CLI_CMD`, `AGENTS_CLI_ARGS`) throughout setup and injected hooks.
- Idempotent: repeated runs refresh assets without duplication and respect previous backups.
- Log clear success/warning messages and respect `AGENTSMD_QUIET=1` for informational output.

### `agentsmd disable`
- Must also run inside a Git repository.
- Removes all automation introduced by `enable`:
  - Deletes managed hooks/scripts (restoring `.agentsmd.bak` hooks where present).
  - Removes merge-driver entries from `.git/info/attributes` and Git config.
  - Clears the `rebuild-agents` alias.
  - Sets `git update-index --no-assume-unchanged` for the managed file when tracked.
- Restores any pre-existing alias or merge-driver configuration that was backed up in `.git/agentsmd-state`, then cleans up the state directory.
- Safe when run without prior enable: skip missing artifacts with notices, exit successfully.

### `agentsmd status`
- Requires a Git repository context.
- Evaluates the automation footprint:
  - Managed `pre-commit` hook present.
  - Merge-driver entry in `.git/info/attributes` plus `merge.agentsmd.driver` config.
  - `alias.rebuild-agents` configured.
  - The managed `AGENTS.md` is tracked and marked assume-unchanged (`git ls-files -v` prefix `h`).
- Emits `Status: ENABLED` only when all checks succeed; otherwise prints `Status: DISABLED` and lists missing/mismatched components.
- When enabled, report the absolute path to `<repo>/.agentsmd` and whether the file is present, empty, or missing.
- Exit non-zero only for unrecoverable errors (e.g., outside Git repo).

### `agentsmd --version`
- Print the CLI's semantic version exactly as defined in the packaged `package.json`.
- Remain accurate immediately after version bumps so `npm version` / release automation does not require manual cache updates.
- Fall back to a development identifier (e.g., `0.0.0-dev`) only when package metadata is unavailable.

### `agentsmd make`
- Must resolve the repository root; fail with `fatal: not a git repository` if `.git` is not found.
- Always targets the root-level managed file (`AGENTS.md` by default).
- Reads developer preferences from `<repo>/.agentsmd`:
  - Missing file → warn once and skip append.
  - Empty or whitespace-only file → log notice, no append.
  - Non-empty file → append raw contents; ensure a trailing newline and separate from existing content with a single blank line when needed.
- Supports inline template tokens inside `.agentsmd`:
  - Recognise `{{ name }}` patterns and replace them with the contents of the first template file discovered in `~/.agentsmd/templates/<name>`.
  - Attempt to load both `<name>` and `<name>.md`, preferring whichever exists first; this keeps `.md` optional while encouraging Markdown naming for editor tooling.
  - Missing templates emit a warning and leave the token untouched so developers can fix their library without losing context.
- Preserve canonical content by stripping any previously appended preferences block before writing; base every regeneration on the committed snapshot (`git show HEAD:AGENTS.md`). Fall back to the working tree file when the path is untracked or HEAD is absent.
- Use atomic writes via temporary files plus `mv`.
- Reject `--dry-run` (reserved for future support) with a descriptive error.

---

## Automation Footprint & Behaviour
- **Merge Driver**: `AGENTS.md` (or override) is mapped to `merge=agentsmd`, and the driver script always prefers the remote (“theirs”) version during merges.
- **Hooks**:
  - `pre-commit`: blocks staging `AGENTS.md`, preserving prior hooks as `<hook>.agentsmd.bak` when they existed.
  - `post-merge` / `post-checkout`: rerun `agentsmd make` when the file changes due to pulls, merges, or checkouts.
  - Shared scripts (`agentsmd-hooks-common.sh`, `agentsmd-merge-driver.sh`) live in `.git/hooks/` and are removed on disable.
- **Alias & Assume-Unchanged**: `git rebuild-agents` mirrors the CLI entry point and `git update-index --assume-unchanged` keeps working-tree noise out of `git status`.
- **State Tracking**: `.git/agentsmd-state/` stores ownership markers and backups so disable can restore a developer’s original config when names overlap.
- **Environment Overrides**: `AGENTS_MD_FILE`, `AGENTS_CLI_CMD`, and `AGENTS_CLI_ARGS` are respected by setup, hooks, and status diagnostics.
- **Failure Modes**: Hooks log warnings (never abort Git operations) if the renderer is unavailable; developers can re-run `agentsmd make` manually.

---

## Workflows

### Setup (First-Run)
1. Developer executes `agentsmd enable` from the repo root.
2. CLI installs automation, backs up pre-existing hooks/config, and performs an initial `agentsmd make` render.
3. `git status` remains clean because `AGENTS.md` is marked assume-unchanged.

### Day-to-Day
1. Developers edit `.agentsmd` as needed.
2. Run `agentsmd make` (or `git rebuild-agents`) to refresh the local file; automation also re-renders after merges or checkouts.
3. Local edits stay unstaged; `status` can confirm everything is healthy and highlight missing setup pieces.

### Teardown / Troubleshooting
1. Run `agentsmd disable` to restore previous hooks/config/aliases and clear automation.
2. Inspect `.git/hooks/` or `.git/agentsmd-state/` if manual cleanup is required.
3. Re-run `agentsmd enable` any time templates, CLI paths, or environment overrides change.

---

## Edge Cases & Error Handling
- Not inside Git repo → commands exit non-zero without touching files.
- `AGENTS.md` not tracked → `status` marks assume-unchanged as missing; `enable` warns when unable to mark the flag.
- HEAD missing or file untracked → `make` falls back to the working-tree file as the base before reapplying preferences.
- Read-only destinations → `make` fails with a clear error before overwriting.
- Concurrent modifications → atomic temp-file writes minimise risk; corruption triggers a retry via manual `agentsmd make`.

---

## Non-Functional Requirements
- **Portability**: All scripts are Bash-compatible on macOS, Linux, and Git for Windows environments.
- **Safety**: Automation never modifies tracked repository files besides the managed `AGENTS.md`; all other changes stay inside `.git`.
- **Observability**: Consistent `[agentsmd]`/`[agents-md]` log prefixes, honouring quiet mode for informational messages while still surfacing warnings/errors.
- **Testability**: Bats coverage for enable/disable/status/make flows, idempotency, repository enforcement, and regeneration behaviour.
- **Resilience**: Setup tolerates repeated runs and restores user state during disable, even when names collide with existing hooks or aliases.

---

## Deliverables
1. CLI command implementations under `lib/agentsmd/commands/` (`enable.sh`, `disable.sh`, `status.sh`, `make.sh`) wired through `bin/agentsmd`.
2. Git asset scripts and templates under `share/agentsmd/git/` supporting install/disable flows and merge driver execution.
3. Automated tests (`tests/specs/*.bats`) covering success paths, error handling, and idempotency.
4. README highlights the core value proposition (features, five-minute tour, CLI reference, automation footprint, troubleshooting) and stays in sync with the supported command surface.

---

## Future Considerations
- Optional `--force` flag for `disable` to skip confirmations if interactive prompts are added.
- More granular diagnostics (timestamps, version info) in `status` output.
- Publish workflow to intentionally stage/commit `AGENTS.md` while still protecting against accidental commits.
- Template/front-matter extensibility in `agentsmd make`, including dry-run or diff modes.
