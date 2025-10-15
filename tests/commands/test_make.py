from __future__ import annotations

import os
from pathlib import Path

import pytest


from conftest import Repo
from tests.helpers.hash_utils import hash_file

def test_creates_agents_md_with_preferences(repo: Repo) -> None:
    prefs = "prefers tabs\n"
    repo.write(".agentsmd", prefs)

    result = repo.run("make")

    assert result.returncode == 0
    assert (repo.path / "AGENTS.md").read_text(encoding="utf-8") == prefs


def test_preserves_existing_content_and_appends_block(repo: Repo) -> None:
    base = "Base instructions\n"
    prefs = "prefers tabs\n"
    repo.write("AGENTS.md", base)
    repo.write(".agentsmd", prefs)

    result = repo.run("make")

    assert result.returncode == 0
    expected = base.rstrip("\n") + "\n\n" + prefs.rstrip("\n") + "\n"
    assert repo.read("AGENTS.md") == expected


def test_make_is_idempotent(repo: Repo) -> None:
    base = "Base instructions\n"
    prefs = "prefers spaces\n"
    repo.write("AGENTS.md", base)
    repo.write(".agentsmd", prefs)

    first = repo.run("make")
    assert first.returncode == 0
    first_hash = hash_file(repo.path / "AGENTS.md")

    second = repo.run("make")
    assert second.returncode == 0
    second_hash = hash_file(repo.path / "AGENTS.md")

    assert first_hash == second_hash


def test_regeneration_uses_head_as_base(repo: Repo) -> None:
    base = "Base instructions\n"
    repo.write("AGENTS.md", base)
    repo.git("add", "AGENTS.md")
    repo.git("commit", "-m", "base snapshot")

    prefs = "prefers tabs\n"
    repo.write(".agentsmd", prefs)
    repo.write("AGENTS.md", "local change\n")

    result = repo.run("make")

    assert result.returncode == 0
    expected = base.rstrip("\n") + "\n\n" + prefs.rstrip("\n") + "\n"
    assert repo.read("AGENTS.md") == expected


def test_missing_preferences_skip_append(repo: Repo) -> None:
    base = "Base instructions\n"
    repo.write("AGENTS.md", base)

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == base


def test_empty_preferences_skip_append(repo: Repo) -> None:
    base = "Base instructions\n"
    repo.write("AGENTS.md", base)
    repo.write(".agentsmd", "")

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == base


def test_template_render_in_preferences(repo: Repo) -> None:
    templates_dir = Path(os.environ["HOME"]) / ".agentsmd" / "templates"
    templates_dir.mkdir(parents=True, exist_ok=True)
    template = "Global guidance\n"
    (templates_dir / "nextjs.md").write_text(template, encoding="utf-8")
    prefs_header = "Developer preferences\n"
    repo.write(".agentsmd", prefs_header + "{{ nextjs }}\n")

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == prefs_header.rstrip("\n") + "\n\n" + template.rstrip("\n") + "\n"


def test_template_render_in_agents_md(repo: Repo) -> None:
    templates_dir = Path(os.environ["HOME"]) / ".agentsmd" / "templates"
    templates_dir.mkdir(parents=True, exist_ok=True)
    template = "Global guidance\n"
    (templates_dir / "nextjs.md").write_text(template, encoding="utf-8")
    base_header = "Base instructions\n"
    repo.write("AGENTS.md", base_header + "{{ nextjs }}\n")

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == base_header.rstrip("\n") + "\n\n" + template.rstrip("\n") + "\n"


@pytest.mark.parametrize(
    "prefix_content",
    ["Prefix guidance", "Prefix guidance\n", "Prefix guidance\n\n"],
)
def test_template_renders_single_blank_line_after_prefix(repo: Repo, prefix_content: str) -> None:
    templates_dir = Path(os.environ["HOME"]) / ".agentsmd" / "templates"
    templates_dir.mkdir(parents=True, exist_ok=True)
    (templates_dir / "nextjs.md").write_text("Rendered template\n", encoding="utf-8")
    repo.write("AGENTS.md", f"{prefix_content}{{{{ nextjs }}}}\n")

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == "Prefix guidance\n\nRendered template\n"


@pytest.mark.parametrize(
    "template_content",
    [
        "Rendered template",
        "Rendered template\n",
        "\nRendered template",
        "\nRendered template\n\n",
    ],
)
def test_template_normalizes_internal_newlines_and_suffix_spacing(
    repo: Repo, template_content: str
) -> None:
    templates_dir = Path(os.environ["HOME"]) / ".agentsmd" / "templates"
    templates_dir.mkdir(parents=True, exist_ok=True)
    (templates_dir / "nextjs.md").write_text(template_content, encoding="utf-8")
    repo.write("AGENTS.md", "Prefix guidance\n{{ nextjs }}\nSuffix details\n")

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == "Prefix guidance\n\nRendered template\n\nSuffix details\n"


@pytest.mark.parametrize(
    "suffix_content",
    ["Suffix details", "Suffix details\n", "\nSuffix details", "\nSuffix details\n\n"],
)
def test_template_renders_single_blank_line_before_suffix_content(
    repo: Repo, suffix_content: str
) -> None:
    templates_dir = Path(os.environ["HOME"]) / ".agentsmd" / "templates"
    templates_dir.mkdir(parents=True, exist_ok=True)
    (templates_dir / "nextjs.md").write_text("Rendered template\n", encoding="utf-8")
    repo.write("AGENTS.md", f"{{{{ nextjs }}}}{suffix_content}")

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == "Rendered template\n\nSuffix details\n"


@pytest.mark.parametrize(
    "template_content",
    [
        "Solo-render template",
        "Solo-render template\n",
        "\nSolo-render template",
        "\nSolo-render template\n\n",
    ],
)
def test_template_without_prefix_or_suffix_normalizes_newlines(
    repo: Repo, template_content: str
) -> None:
    templates_dir = Path(os.environ["HOME"]) / ".agentsmd" / "templates"
    templates_dir.mkdir(parents=True, exist_ok=True)
    (templates_dir / "nextjs.md").write_text(template_content, encoding="utf-8")
    repo.write("AGENTS.md", "{{ nextjs }}")

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == "Solo-render template\n"


def test_missing_template_generates_warning(repo: Repo) -> None:
    repo.write(".agentsmd", "Before\n\n{{ missing }}\n")

    result = repo.run("make")

    assert result.returncode == 0
    assert "template 'missing' not found" in result.stderr
    assert repo.read("AGENTS.md") == "Before\n\n{{ missing }}\n"


@pytest.mark.parametrize(
    "base_content",
    ["Base instructions", "Base instructions\n", "Base instructions\n\n"],
)
def test_single_blank_line_between_sections(repo: Repo, base_content: str) -> None:
    repo.write("AGENTS.md", base_content)
    repo.write(".agentsmd", "Appended prefs\n")

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == "Base instructions\n\nAppended prefs\n"


@pytest.mark.parametrize(
    "prefs_content",
    ["Appended prefs", "Appended prefs\n", "Appended prefs\n\n"],
)
def test_appended_content_single_trailing_newline(repo: Repo, prefs_content: str) -> None:
    repo.write("AGENTS.md", "Base instructions\n")
    repo.write(".agentsmd", prefs_content)

    result = repo.run("make")

    assert result.returncode == 0
    assert repo.read("AGENTS.md") == "Base instructions\n\nAppended prefs\n"
