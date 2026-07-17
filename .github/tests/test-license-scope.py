#!/usr/bin/env python3
"""Verify that repository reuse terms are explicit and cover every artifact."""

from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]


def repository_paths() -> list[str]:
    """Return tracked and untracked, non-ignored files in the worktree."""
    result = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return sorted(set(result.stdout.splitlines()))


def artifact_class(path: str) -> str | None:
    if path in {"LICENSE", "CONTENT-LICENSE.md"}:
        return "governing"
    if path.startswith(".github/") or path == "assets/.gitkeep":
        return "software"
    if (
        path == "README.md"
        or path.startswith("docs/")
        or path in {"contribution-grid.svg", "contribution-grid-mobile.svg"}
    ):
        return "content"
    if path == "assets/github-stats.svg":
        return "third-party"
    return None


class LicenseScopeTests(unittest.TestCase):
    def test_root_mit_license_is_detectable(self) -> None:
        license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
        self.assertTrue(license_text.startswith("MIT License\n"))
        self.assertIn("Copyright (c) 2026 Brad Groux", license_text)
        self.assertIn(
            "Permission is hereby granted, free of charge, to any person obtaining a copy",
            license_text,
        )
        self.assertIn('THE SOFTWARE IS PROVIDED "AS IS"', license_text)

    def test_content_notice_defines_scope_and_attribution(self) -> None:
        notice = (ROOT / "CONTENT-LICENSE.md").read_text(encoding="utf-8")

        for required in (
            "https://creativecommons.org/licenses/by/4.0/",
            "Brad Groux",
            ".github/**",
            "MIT License",
            "README.md",
            "docs/**",
            "contribution-grid.svg",
            "contribution-grid-mobile.svg",
            "assets/github-stats.svg",
            "Title",
            "Source",
            "License",
            "changes",
            "third-party",
            "not included",
        ):
            with self.subTest(required=required):
                self.assertIn(required, notice)

    def test_readme_links_both_governing_files(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("[MIT](LICENSE)", readme)
        self.assertIn("[CC BY 4.0](CONTENT-LICENSE.md)", readme)

    def test_every_repository_path_has_exactly_one_artifact_class(self) -> None:
        paths = repository_paths()
        unclassified = [path for path in paths if artifact_class(path) is None]

        self.assertEqual(unclassified, [], f"unclassified paths: {unclassified}")
        self.assertIn("software", {artifact_class(path) for path in paths})
        self.assertIn("content", {artifact_class(path) for path in paths})
        self.assertIn("third-party", {artifact_class(path) for path in paths})


if __name__ == "__main__":
    unittest.main()
