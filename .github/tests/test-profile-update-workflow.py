#!/usr/bin/env python3
"""Verify the generated-profile workflow's cadence and publication boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
PROFILE_WORKFLOW = WORKFLOWS / "update-profile.yml"

assert PROFILE_WORKFLOW.is_file(), "the consolidated update-profile workflow is required"
assert not (WORKFLOWS / "readme-stats.yml").exists(), "the independent stats schedule must be removed"
assert not (WORKFLOWS / "update-grid.yml").exists(), "the independent grid schedule must be removed"

workflow = PROFILE_WORKFLOW.read_text(encoding="utf-8")
all_workflows = "\n".join(path.read_text(encoding="utf-8") for path in WORKFLOWS.glob("*.yml"))

assert all_workflows.count("  schedule:") == 1, "exactly one scheduled workflow is allowed"
assert "- cron: '0 6 * * *'" in workflow, "profile assets must refresh once daily"
assert "  workflow_dispatch:" in workflow, "manual refresh must remain available"
assert "concurrency:" in workflow and "cancel-in-progress: false" in workflow
assert "needs: [generate-stats, generate-grid]" in workflow
assert "if: always()" not in workflow, "publication must be skipped when either generator fails"
assert workflow.count("publish-generated-pr.sh") == 1, "there must be one conditional publication call"
assert "automation/profile-activity" in workflow

for path in (
    "assets/github-stats.svg",
    "contribution-grid.svg",
    "contribution-grid-mobile.svg",
    "README.md",
):
    assert path in workflow, f"combined publication must allow-list {path}"

assert "git push" not in workflow
assert "gh pr merge" not in workflow
assert "gh pr review" not in workflow

print("profile update workflow tests passed")
