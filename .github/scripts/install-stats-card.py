#!/usr/bin/env python3
"""Validate a generated GitHub stats card and install it atomically."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys
import tempfile
import xml.etree.ElementTree as ET


EXPECTED_STATS = {"stars", "commits", "prs", "issues", "contribs"}
ERROR_MARKERS = (
    "something went wrong",
    "cannot read properties of undefined",
    "github-readme-stats error",
)


class ValidationError(Exception):
    """Raised when a candidate stats card does not meet the public contract."""


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def positive_number(value: str | None, field: str) -> None:
    if not value:
        raise ValidationError(f"missing {field}")
    try:
        number = float(value.removesuffix("px"))
    except ValueError as error:
        raise ValidationError(f"invalid {field}: {value}") from error
    if number <= 0:
        raise ValidationError(f"{field} must be positive")


def validate(candidate: Path) -> None:
    if not candidate.is_file():
        raise ValidationError(f"candidate does not exist: {candidate}")

    try:
        tree = ET.parse(candidate)
    except ET.ParseError as error:
        raise ValidationError(f"invalid SVG XML: {error}") from error

    root = tree.getroot()
    if local_name(root.tag) != "svg":
        raise ValidationError("root element must be svg")
    if root.get("role") != "img":
        raise ValidationError('root svg must declare role="img"')

    positive_number(root.get("width"), "width")
    positive_number(root.get("height"), "height")
    if not root.get("viewBox"):
        raise ValidationError("missing viewBox")

    elements = list(root.iter())
    title = next((element for element in elements if local_name(element.tag) == "title"), None)
    description = next((element for element in elements if local_name(element.tag) == "desc"), None)
    title_text = "".join(title.itertext()).strip() if title is not None else ""
    description_text = "".join(description.itertext()).strip() if description is not None else ""

    if "github stats" not in title_text.lower():
        raise ValidationError("missing GitHub Stats title")
    if not description_text:
        raise ValidationError("missing stats description")
    text = " ".join("".join(element.itertext()) for element in elements).lower()
    for marker in ERROR_MARKERS:
        if marker in text:
            raise ValidationError(f"upstream error marker found: {marker}")

    test_ids = {element.get("data-testid") for element in elements if element.get("data-testid")}
    if "message" in test_ids:
        raise ValidationError("upstream error message element found")

    missing_stats = EXPECTED_STATS - test_ids
    if missing_stats:
        raise ValidationError(
            "missing expected stats: " + ", ".join(sorted(missing_stats))
        )

    if not title.get("id") or not description.get("id"):
        raise ValidationError("stats title and description must have IDs")
    expected_labels = {title.get("id"), description.get("id")}
    actual_labels = set(root.get("aria-labelledby", "").split())
    if not actual_labels or not actual_labels <= expected_labels or description.get("id") not in actual_labels:
        raise ValidationError("root svg must reference its stats description")


def normalized_payload(candidate: Path) -> bytes:
    """Ensure the embedded SVG references both its title and description."""
    payload = candidate.read_text(encoding="utf-8")
    root_match = re.search(r"<svg\b[^>]*>", payload, flags=re.DOTALL)
    if root_match is None:
        raise ValidationError("root svg opening tag is missing")
    root_tag = root_match.group(0)
    tree_root = ET.fromstring(payload)
    elements = list(tree_root.iter())
    title = next(element for element in elements if local_name(element.tag) == "title")
    description = next(element for element in elements if local_name(element.tag) == "desc")
    labels = f"{title.get('id')} {description.get('id')}"
    if re.search(r"\baria-labelledby\s*=", root_tag):
        normalized_tag = re.sub(
            r"\baria-labelledby\s*=\s*(['\"]).*?\1",
            f'aria-labelledby="{labels}"',
            root_tag,
            count=1,
            flags=re.DOTALL,
        )
    else:
        normalized_tag = root_tag[:-1] + f' aria-labelledby="{labels}">'
    return (payload[:root_match.start()] + normalized_tag + payload[root_match.end():]).encode("utf-8")


def install(candidate: Path, target: Path) -> None:
    validate(candidate)
    payload = normalized_payload(candidate)

    candidate = candidate.resolve()
    target = target.resolve()
    if candidate == target:
        raise ValidationError("candidate and target must be different paths")

    target.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            prefix=f".{target.name}.",
            suffix=".tmp",
            dir=target.parent,
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            temporary.write(payload)
            temporary.flush()
            os.fsync(temporary.fileno())

        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, target)
    finally:
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink()


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: install-stats-card.py CANDIDATE_SVG TARGET_SVG",
            file=sys.stderr,
        )
        return 2

    candidate = Path(sys.argv[1])
    target = Path(sys.argv[2])
    try:
        install(candidate, target)
    except (OSError, ValidationError) as error:
        print(f"stats card rejected: {error}", file=sys.stderr)
        return 1

    print(f"installed validated stats card: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
