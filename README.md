<h1 align="center">agentsmd</h1>
<p align="center">Templates and preferences for your <code>AGENTS.md</code> instructions.</p>

<p align="center">
<code>npm install -g @adiasg/agentsmd</code> · <code>npx @adiasg/agentsmd &lt;command&gt;</code>
</p>

---

> **agentsmd** adds templating and local `.agentsmd` preferences to `AGENTS.md` while keeping the tracked source clean.

## Features

* 🧾 **Personal Overlays** – `agentsmd make` rebuilds `AGENTS.md` by appending your `.agentsmd` preferences & templates onto the committed snapshot.
* 🔄 **Automate the Refresh** – `agentsmd enable` hooks Git so `AGENTS.md` regenerates on pulls/checkouts and silently ignores your local rendered copy; `agentsmd disable` rolls back the Git hooks.
* 🧩 **Reusable Templates** – Place `{{ name }}` tokens in `AGENTS.md` or `.agentsmd` to pull snippets from `~/.agentsmd/templates/<name>[.md]`, sharing guidance across projects.
* 🧰 **Local Install Only** – Everything the CLI writes stays in your working tree — no global state or remote services required.

---

## 🚀 Quick Tour
```bash
# 1. Install
npm install -g @adiasg/agentsmd

# 2. Drop reusable templates into your home library
mkdir -p ~/.agentsmd/templates
echo "Never run npm run dev yourself." > ~/.agentsmd/templates/nextjs.md
# Refer to this template in AGENTS.md or .agentsmd with {{ nextjs }}
echo "{{ nextjs }}" > .agentsmd

# 3. Place your personal overlay (kept local)
echo "Don't hardcode constants - instead place them in a constants.ts file." >> .agentsmd

# 4. Render templates and append .agentsmd to AGENTS.md
agentsmd make

# 5. (Optional) Git automation for regeneration & ignoring file
agentsmd enable
agentsmd status
agentsmd disable
```

---

## 🧩 Templating Quick Start

Keep the shared `AGENTS.md` focused on repository guidelines while layering your personal preferences in `.agentsmd`. Anywhere you place `{{ name }}` inside the file, `agentsmd make` will inline content from your home template library at `~/.agentsmd/templates/<name>`.  
For each location the lookup checks both `<name>` and `<name>.md`, so you can opt in to the Markdown suffix without breaking existing snippets.

**Note:** Rendering templates requires Python 3 to be available as `python3` or `python`.

Example:

```markdown
### ~/.agentsmd/templates/nextjs.md

- Never run `npm run dev`.
```

```markdown
### .agentsmd

### Developer Preferences

- Use orange hues for the accent colors.
{{ nextjs }}
```

```
agentsmd make
```

The resulting `AGENTS.md`: 

```markdown
<Orignial AGENTS.md contents>

### Developer Preferences

- Use orange hues for the accent colors.
- Never run `npm run dev`.
```

---

## 🧰 CLI Reference

| Command | What it does |
|---------|--------------|
| `agentsmd make` | Rebuilds `AGENTS.md` from the last committed version plus your `.agentsmd` preferences and templates. |
| `agentsmd enable` | Enables local Git automation for regenerating file on pull/checkout. Installs hooks, merge driver, `git rebuild-agents` alias, and marks `AGENTS.md` assume-unchanged. |
| `agentsmd disable` | Removes all installed local Git automation, restores backed up hooks/config. |
| `agentsmd status` | Prints installation status. |
| `agentsmd --version` | Shows the version. |

Run `agentsmd help <command>` for detailed usage text.

---

## 🧱 What `agentsmd enable` Installs

- **Hooks** – Managed `pre-commit`, `post-merge`, and `post-checkout` scripts that call `agentsmd make` when appropriate. Original hooks are saved as `<hook>.agentsmd.bak`.
- **Merge driver** – Adds `merge=agentsmd` to `.git/info/attributes` so merge conflicts prefer the remote `AGENTS.md`.
- **Git alias** – `git rebuild-agents` points back to the CLI for quick rebuilds.
- **Assume unchanged** – `AGENTS.md` is kept out of `git status` noise but remains editable locally.
- **State directory** – `.git/agentsmd-state/` tracks backups and ownership markers, enabling clean disable flows.

Disable removes each artifact and puts your repo back exactly as it was.

---

## 🛠 Contributing

We welcome pull requests! Before opening one:
- Ensure new behaviour is covered by tests where practical.
- Run `npm run lint` and `npm run test`.
- Update documentation (`README.md`, `docs/PRD.md`, and relevant assets) to match your changes.

`.devcontainer/` has an environment with the required tooling (Node LTS, `shellcheck`, `shfmt`, `bats`).

---

## ❓ Troubleshooting

- **"fatal: not a git repository"** – Run commands inside a clone; automation never touches directories without `.git`.
- **`AGENTS.md` still showing in git status** – Ensure the file is tracked; otherwise `git update-index --assume-unchanged` cannot be set.
- **HEAD missing or `AGENTS.md` untracked** – `agentsmd make` falls back to the working-tree `AGENTS.md` at the repo root before reapplying preferences.
- **`Status: DISABLED` with missing components** – Run `agentsmd enable` to reinstall; it is safe to re-run and will restore missing pieces.
- **Missing template referenced** – The token is left as `{{ name }}` and a warning is printed; fix files in `~/.agentsmd/templates/`.

---

## 📄 License

MIT License. See [`LICENSE`](LICENSE).
