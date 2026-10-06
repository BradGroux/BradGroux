#!/usr/bin/env python3
"""Set calendar-year public contribution metadata on a generated stats card."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


CONTRIBUTIONS_QUERY = """
query($login: String!, $start: DateTime!, $end: DateTime!) {
  user(login: $login) {
    contributionsCollection(from: $start, to: $end) {
      commitContributionsByRepository(maxRepositories: 100) {
        repository { nameWithOwner isPrivate owner { login } }
      }
      issueContributionsByRepository(maxRepositories: 100) {
        repository { nameWithOwner isPrivate owner { login } }
      }
      pullRequestContributionsByRepository(maxRepositories: 100) {
        repository { nameWithOwner isPrivate owner { login } }
      }
      repositoryContributions(first: 100) {
        totalCount
        nodes { repository { nameWithOwner isPrivate owner { login } } }
      }
    }
  }
}
"""

YEAR_LABEL = re.compile(r"Contributed to \((?:last year|\d{4})\)")


class StatsCardError(Exception):
    """Raised when a calendar-year card cannot be produced safely."""


def calendar_window(year: int) -> tuple[str, str]:
    now = datetime.now(timezone.utc)
    start = datetime(year, 1, 1, tzinfo=timezone.utc)
    end = min(now, datetime(year + 1, 1, 1, tzinfo=timezone.utc))
    if end <= start:
        raise StatsCardError(f"{year} has not started")
    return start.isoformat().replace("+00:00", "Z"), end.isoformat().replace(
        "+00:00", "Z"
    )


def fetch_contributed_repository_count(username: str, year: int) -> int:
    """Count public, externally owned repositories contributed to during year."""
    start, end = calendar_window(year)
    command = [
        "gh",
        "api",
        "graphql",
        "-f",
        f"query={CONTRIBUTIONS_QUERY}",
        "-f",
        f"login={username}",
        "-f",
        f"start={start}",
        "-f",
        f"end={end}",
    ]
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
        collection = json.loads(result.stdout)["data"]["user"][
            "contributionsCollection"
        ]
    except (
        subprocess.CalledProcessError,
        KeyError,
        TypeError,
        json.JSONDecodeError,
    ) as error:
        raise StatsCardError("could not fetch calendar-year contributions") from error

    groups = [
        collection["commitContributionsByRepository"],
        collection["issueContributionsByRepository"],
        collection["pullRequestContributionsByRepository"],
    ]
    if any(len(group) == 100 for group in groups):
        raise StatsCardError("a contribution category reached the 100-repository limit")

    created = collection["repositoryContributions"]
    if created["totalCount"] != len(created["nodes"]):
        raise StatsCardError("repository contributions were truncated")
    groups.append(created["nodes"])

    repositories = {
        contribution["repository"]["nameWithOwner"]
        for group in groups
        for contribution in group
        if not contribution["repository"]["isPrivate"]
        and contribution["repository"]["owner"]["login"].casefold()
        != username.casefold()
    }
    return len(repositories)


def customize(candidate: Path, year: int, contributed_to: int) -> str:
    svg = candidate.read_text(encoding="utf-8")
    commit_label = re.compile(rf"Total Commits\s+\({year}\)")
    if len(commit_label.findall(svg)) != 2:
        raise StatsCardError(
            f"candidate must contain two Total Commits ({year}) labels"
        )

    svg, label_count = YEAR_LABEL.subn(f"Contributed to ({year})", svg)
    if label_count != 2:
        raise StatsCardError("candidate must contain two contributed-to year labels")

    description_value = re.compile(
        rf"(Contributed to \({year}\): )\d[\d,]*(?:\.\d+)?[kK]?"
    )
    svg, description_count = description_value.subn(
        rf"\g<1>{contributed_to}", svg, count=1
    )
    if description_count != 1:
        raise StatsCardError("candidate must contain one described contribs value")

    markers = list(re.finditer(r'data-testid="contribs"', svg))
    if len(markers) != 1:
        raise StatsCardError("candidate must contain one contribs value")

    value_start = svg.find(">", markers[0].end())
    value_end = svg.find("</text>", value_start)
    if value_start < 0 or value_end < 0:
        raise StatsCardError("could not locate contribs text value")

    current_value = svg[value_start + 1 : value_end]
    replacement, value_count = re.subn(
        r"\d[\d,]*(?:\.\d+)?[kK]?", str(contributed_to), current_value, count=1
    )
    if value_count != 1:
        raise StatsCardError("candidate must contain one numeric contribs value")

    return svg[: value_start + 1] + replacement + svg[value_end:]


def install(svg: str, target: Path) -> None:
    validator = Path(__file__).with_name("install-stats-card.py")
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".svg", encoding="utf-8", delete=False
    ) as temporary:
        temporary.write(svg)
        candidate = Path(temporary.name)
    try:
        subprocess.run(
            [sys.executable, str(validator), str(candidate), str(target)], check=True
        )
    finally:
        candidate.unlink(missing_ok=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Apply calendar-year contributed-repository data to a stats card "
            "already generated with commits_year=YEAR."
        )
    )
    parser.add_argument("candidate", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--username", required=True)
    parser.add_argument("--year", required=True, type=int)
    parser.add_argument(
        "--contributed-to",
        type=int,
        help="Use a supplied repository count instead of querying GitHub.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        contributed_to = (
            args.contributed_to
            if args.contributed_to is not None
            else fetch_contributed_repository_count(args.username, args.year)
        )
        if contributed_to < 0:
            raise StatsCardError("contributed-to count cannot be negative")
        install(customize(args.candidate, args.year, contributed_to), args.target)
    except (OSError, StatsCardError, subprocess.CalledProcessError) as error:
        print(f"calendar-year stats card rejected: {error}", file=sys.stderr)
        return 1

    print(
        f"installed {args.year} stats card with {contributed_to} contributed repositories: "
        f"{args.target}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
