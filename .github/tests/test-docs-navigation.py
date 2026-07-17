#!/usr/bin/env python3
"""Verify semantic profile content and durable writing navigation."""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
README = ROOT / "README.md"
DOCS_INDEX = ROOT / "docs" / "README.md"

PACKAGES = {
    "codex-managed-agent-patterns": {
        "canonical": "codex-managed-agent-patterns.md",
        "support": ("prompt.md", "research.md"),
    },
    "you-dont-have-to-wait-to-build-it": {
        "canonical": "you-dont-have-to-wait-to-build-it.md",
        "support": ("prompt.md", "research.md"),
    },
}


def assert_relative_links_resolve(path: Path) -> None:
    content = path.read_text(encoding="utf-8")
    for target in re.findall(r"\[[^]]+\]\(([^)]+)\)", content):
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        resolved = (path.parent / target.split("#", 1)[0]).resolve()
        if not resolved.exists():
            raise AssertionError(f"{path.relative_to(ROOT)} has a broken relative link: {target}")


readme = README.read_text(encoding="utf-8")
stack = readme.split("## The Stack", 1)[1].split("\n## ", 1)[0]
assert "```" not in stack, "The Stack must not use a code fence"
for label in ("Application development", "Platforms and operations", "AI systems"):
    assert f"**{label}:**" in stack, f"The Stack is missing the {label} semantic group"

for path in (
    "docs/README.md",
    "docs/codex-managed-agent-patterns/codex-managed-agent-patterns.md",
    "docs/you-dont-have-to-wait-to-build-it/you-dont-have-to-wait-to-build-it.md",
):
    assert f"]({path})" in readme, f"README must link directly to {path}"

assert DOCS_INDEX.is_file(), "docs/README.md is required"
index = DOCS_INDEX.read_text(encoding="utf-8")
for label in ("Audience", "Published", "Canonical article", "Practical guide", "Research notes", "Reusable prompt"):
    assert label in index, f"docs index is missing the reader-facing label: {label}"

for package, contract in PACKAGES.items():
    package_dir = ROOT / "docs" / package
    canonical = package_dir / contract["canonical"]
    assert canonical.name in index, f"docs index must link to {canonical.name}"
    for support_name in contract["support"]:
        support = package_dir / support_name
        content = support.read_text(encoding="utf-8")
        assert f"]({canonical.name})" in content, f"{support.relative_to(ROOT)} must link to its canonical article"
        assert "](../README.md)" in content, f"{support.relative_to(ROOT)} must link to the writing index"

for path in (README, DOCS_INDEX, *sorted((ROOT / "docs").glob("*/*.md"))):
    assert_relative_links_resolve(path)

print("docs navigation tests passed")
