#!/usr/bin/env python3
"""Update README activity summaries from validated repository-owned data."""

from __future__ import annotations

from datetime import date
import json
import os
from pathlib import Path
import sys
import tempfile
import xml.etree.ElementTree as ET


class UpdateError(Exception):
    """Raised when an activity summary cannot be updated safely."""


EXPECTED_STATS = {"stars", "commits", "prs", "issues", "contribs"}


def replace_between_markers(readme: str, kind: str, content: str) -> str:
    start = f"<!-- {kind}-summary:start -->"
    end = f"<!-- {kind}-summary:end -->"
    if readme.count(start) != 1 or readme.count(end) != 1:
        raise UpdateError(f"README must contain exactly one {kind} summary marker pair")
    start_index = readme.index(start)
    end_index = readme.index(end, start_index)
    if end_index < start_index:
        raise UpdateError(f"README {kind} summary markers are out of order")
    return readme[:start_index] + f"{start}\n{content}\n{end}" + readme[end_index + len(end):]


def stats_summary(path: Path) -> str:
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as error:
        raise UpdateError(f"invalid stats card: {error}") from error
    values: dict[str, str] = {}
    for element in root.iter():
        test_id = element.get("data-testid")
        if test_id in EXPECTED_STATS:
            value = "".join(element.itertext()).strip().replace(",", "")
            if not value.isdigit():
                raise UpdateError(f"invalid {test_id} value")
            values[test_id] = f"{int(value):,}"
    missing = EXPECTED_STATS - set(values)
    if missing:
        raise UpdateError("missing expected stats: " + ", ".join(sorted(missing)))
    return (
        f"<strong>GitHub stats:</strong> {values['stars']} stars · {values['commits']} commits in the last year · "
        f"{values['prs']} pull requests · {values['issues']} issues · contributions to "
        f"{values['contribs']} repositories in the last year."
    )


def contribution_summary(path: Path) -> str:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        calendar = payload["data"]["user"]["contributionsCollection"]["contributionCalendar"]
        total = calendar["totalContributions"]
        days = [day for week in calendar["weeks"] for day in week["contributionDays"]]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise UpdateError(f"invalid contribution response: {error}") from error
    if payload.get("errors"):
        raise UpdateError("GraphQL response contains errors")
    if not isinstance(total, int) or isinstance(total, bool) or total < 0:
        raise UpdateError("invalid contribution total")
    active: list[tuple[int, date]] = []
    for day in days:
        try:
            count = day["contributionCount"]
            day_date = date.fromisoformat(day["date"])
        except (KeyError, TypeError, ValueError) as error:
            raise UpdateError(f"invalid contribution day: {error}") from error
        if not isinstance(count, int) or isinstance(count, bool) or count < 0:
            raise UpdateError("invalid contribution count")
        if count:
            active.append((count, day_date))
    observed_total = sum(day["contributionCount"] for day in days)
    if observed_total != total:
        raise UpdateError(
            f"contribution total is {total}, but daily counts sum to {observed_total}"
        )
    if not active:
        return f"<strong>Contribution activity:</strong> {total:,} contributions in the last year; no active days."
    peak_count, peak_date = max(active, key=lambda item: (item[0], item[1]))
    return (
        f"<strong>Contribution activity:</strong> {total:,} contributions in the last year across {len(active):,} active days; "
        f"peak day: {peak_count:,} contributions on {peak_date.strftime('%B %-d, %Y')}. "
        "Activity levels use distinct shapes as well as color."
    )


def write_atomic(path: Path, content: str) -> None:
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            prefix=f".{path.name}.", dir=path.parent, mode="w", encoding="utf-8", delete=False
        ) as temporary:
            temporary_path = Path(temporary.name)
            temporary.write(content)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, path)
    finally:
        if temporary_path and temporary_path.exists():
            temporary_path.unlink()


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[1] not in {"stats", "grid"}:
        print("usage: update-readme-activity.py (stats|grid) SOURCE README", file=sys.stderr)
        return 2
    source, readme_path = Path(sys.argv[2]), Path(sys.argv[3])
    try:
        readme = readme_path.read_text(encoding="utf-8")
        if sys.argv[1] == "stats":
            updated = replace_between_markers(readme, "github-stats", stats_summary(source))
        else:
            updated = replace_between_markers(readme, "contribution", contribution_summary(source))
        write_atomic(readme_path, updated)
    except (OSError, UpdateError) as error:
        print(f"README activity update rejected: {error}", file=sys.stderr)
        return 1
    print(f"updated {sys.argv[1]} summary in {readme_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
