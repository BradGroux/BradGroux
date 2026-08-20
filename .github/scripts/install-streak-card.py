#!/usr/bin/env python3
"""Validate a generated GitHub streak card and install it atomically."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys
import tempfile
import xml.etree.ElementTree as ET


EXPECTED_LABELS = {
    "total contributions",
    "current streak",
    "longest streak",
}
ERROR_MARKERS = (
    "failed to retrieve contributions",
    "github api issue",
    "something went wrong",
    "unable to fetch contributions",
    "github readme streak stats error",
)


class ValidationError(Exception):
    """Raised when a candidate does not meet the public card contract."""


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

    positive_number(root.get("width"), "width")
    positive_number(root.get("height"), "height")
    if not root.get("viewBox"):
        raise ValidationError("missing viewBox")

    text = " ".join("".join(element.itertext()) for element in root.iter())
    normalized_text = " ".join(text.split()).lower()
    for marker in ERROR_MARKERS:
        if marker in normalized_text:
            raise ValidationError(f"upstream error marker found: {marker}")

    missing_labels = EXPECTED_LABELS - {
        label for label in EXPECTED_LABELS if label in normalized_text
    }
    if missing_labels:
        raise ValidationError(
            "missing expected labels: " + ", ".join(sorted(missing_labels))
        )

    if not re.search(r"\d", normalized_text):
        raise ValidationError("missing streak values")


def install(candidate: Path, target: Path) -> None:
    validate(candidate)

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
            with candidate.open("rb") as source:
                for line in source:
                    content = line.rstrip(b"\r\n")
                    newline = line[len(content) :]
                    temporary.write(content.rstrip(b" \t") + newline)
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
            "usage: install-streak-card.py CANDIDATE_SVG TARGET_SVG",
            file=sys.stderr,
        )
        return 2

    candidate = Path(sys.argv[1])
    target = Path(sys.argv[2])
    try:
        install(candidate, target)
    except (OSError, ValidationError) as error:
        print(f"streak card rejected: {error}", file=sys.stderr)
        return 1

    print(f"installed validated streak card: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
