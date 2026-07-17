#!/usr/bin/env python3
"""Render accessible desktop and mobile contribution-grid SVGs."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
import xml.etree.ElementTree as ET


SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

BACKGROUND = "#1a1b27"
EMPTY = "#2a2e3f"
LEVEL_COLORS = (EMPTY, "#3b1f7e", "#5b2fb5", "#7c3aed", "#8b5cf6")
LABEL = "#a9b1d6"
ACCENT = "#70a5fd"
CUE = "#f5f7ff"
FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")


class RenderError(Exception):
    """Raised when source activity data cannot be rendered safely."""


@dataclass(frozen=True)
class Day:
    count: int | None
    date_value: date | None
    level: int


@dataclass(frozen=True)
class Grid:
    total: int
    weeks: tuple[tuple[Day, ...], ...]
    month_labels: tuple[tuple[int, str], ...]
    description: str


def tag(name: str) -> str:
    return f"{{{SVG_NS}}}{name}"


def local_name(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def level_for_count(count: int) -> int:
    if count == 0:
        return 0
    if count <= 3:
        return 1
    if count <= 6:
        return 2
    if count <= 9:
        return 3
    return 4


def load_json(path: Path) -> Grid:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        calendar = payload["data"]["user"]["contributionsCollection"]["contributionCalendar"]
        total = calendar["totalContributions"]
        raw_weeks = calendar["weeks"]
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise RenderError(f"invalid contribution response: {error}") from error

    if payload.get("errors"):
        raise RenderError("GraphQL response contains errors")
    if not isinstance(total, int) or isinstance(total, bool) or total < 0:
        raise RenderError("invalid contribution response: totalContributions must be a nonnegative integer")
    if not isinstance(raw_weeks, list):
        raise RenderError("invalid contribution response: weeks must be an array")

    weeks: list[tuple[Day, ...]] = []
    month_labels: list[tuple[int, str]] = []
    last_month: int | None = None
    active: list[Day] = []
    for week_index, raw_week in enumerate(raw_weeks):
        if not isinstance(raw_week, dict) or not isinstance(raw_week.get("contributionDays"), list):
            raise RenderError("invalid contribution response: every week needs contributionDays")
        if len(raw_week["contributionDays"]) > 7:
            raise RenderError("invalid contribution response: a week cannot contain more than seven days")
        days: list[Day] = []
        for raw_day in raw_week["contributionDays"]:
            try:
                count = raw_day["contributionCount"]
                day_date = date.fromisoformat(raw_day["date"])
            except (KeyError, TypeError, ValueError) as error:
                raise RenderError(f"invalid contribution response: malformed day: {error}") from error
            if not isinstance(count, int) or isinstance(count, bool) or count < 0:
                raise RenderError("invalid contribution response: contributionCount must be a nonnegative integer")
            day = Day(count=count, date_value=day_date, level=level_for_count(count))
            days.append(day)
            if count:
                active.append(day)
            if day_date.month != last_month and day_date.day <= 7:
                month_labels.append((week_index, MONTHS[day_date.month - 1]))
                last_month = day_date.month
        weeks.append(tuple(days))

    if active:
        peak = max(active, key=lambda item: (item.count or 0, item.date_value or date.min))
        peak_date = peak.date_value.strftime("%B %-d, %Y") if peak.date_value else "unknown"
        description = (
            f"{total:,} contributions in the last year across {len(active):,} active days. "
            f"The busiest day had {peak.count:,} contributions on {peak_date}. "
            "Activity levels use distinct shapes as well as color."
        )
    else:
        description = f"{total:,} contributions in the last year. No active days."

    observed_total = sum(day.count or 0 for week in weeks for day in week)
    if observed_total != total:
        raise RenderError(
            f"invalid contribution response: totalContributions is {total}, but daily counts sum to {observed_total}"
        )

    return Grid(total, tuple(weeks), tuple(month_labels), description)


def load_legacy_svg(path: Path) -> Grid:
    """Preserve committed activity levels when live day-level data is unavailable."""
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as error:
        raise RenderError(f"invalid legacy contribution SVG: {error}") from error

    text = " ".join("".join(element.itertext()) for element in root.iter())
    total_match = re.search(r"([0-9,]+) contributions in the last year", text)
    if not total_match:
        raise RenderError("legacy contribution SVG has no total summary")
    total = int(total_match.group(1).replace(",", ""))

    fill_levels = {color.lower(): level for level, color in enumerate(LEVEL_COLORS)}
    cells: list[tuple[int, int, int]] = []
    for element in root.iter():
        if local_name(element.tag) != "rect" or element.get("width") != "11" or element.get("height") != "11":
            continue
        fill = element.get("fill", "").lower()
        if fill not in fill_levels:
            raise RenderError(f"legacy contribution SVG contains an unknown activity color: {fill}")
        cells.append((int(element.get("x", "0")), int(element.get("y", "0")), fill_levels[fill]))
    if not cells:
        raise RenderError("legacy contribution SVG has no contribution cells")

    x_values = sorted({x for x, _, _ in cells})
    y_values = sorted({y for _, y, _ in cells})
    if len(y_values) > 7:
        raise RenderError("legacy contribution SVG contains more than seven day rows")
    by_position = {(x, y): level for x, y, level in cells}
    weeks = tuple(tuple(Day(None, None, by_position.get((x, y), 0)) for y in y_values) for x in x_values)

    month_labels: list[tuple[int, str]] = []
    for element in root.iter():
        if local_name(element.tag) != "text":
            continue
        label = "".join(element.itertext()).strip()
        if label not in MONTHS or not element.get("x"):
            continue
        x = int(float(element.get("x", "0")))
        nearest = min(range(len(x_values)), key=lambda index: abs(x_values[index] - x))
        month_labels.append((nearest, label))

    description = (
        f"{total:,} contributions in the last year. The daily activity levels are preserved "
        "from the last-known-good grid and use distinct shapes as well as color."
    )
    return Grid(total, weeks, tuple(month_labels), description)


def add_text(parent: ET.Element, x: int, y: int, value: str, *, size: int = 12, test_id: str | None = None) -> None:
    attributes = {"x": str(x), "y": str(y), "fill": LABEL, "font-size": str(size), "font-family": FONT}
    if test_id:
        attributes["data-testid"] = test_id
    element = ET.SubElement(parent, tag("text"), attributes)
    element.text = value


def add_cell(parent: ET.Element, x: int, y: int, day: Day, cell: int = 11) -> None:
    fill = LEVEL_COLORS[day.level]
    attributes = {
        "x": str(x), "y": str(y), "width": str(cell), "height": str(cell), "rx": "2",
        "fill": fill, "data-level": str(day.level),
    }
    if day.date_value:
        attributes["data-date"] = day.date_value.isoformat()
    if day.count is not None:
        attributes["data-count"] = str(day.count)
    ET.SubElement(parent, tag("rect"), attributes)
    if day.level == 0:
        return

    common = {"data-cell-fill": fill, "aria-hidden": "true"}
    if day.level == 1:
        ET.SubElement(parent, tag("circle"), {
            **common, "data-cue": "dot", "cx": str(x + cell / 2), "cy": str(y + cell / 2), "r": "1.7", "fill": CUE,
        })
    elif day.level == 2:
        ET.SubElement(parent, tag("rect"), {
            **common, "data-cue": "bar", "x": str(x + 2), "y": str(y + 4.5), "width": str(cell - 4), "height": "2", "rx": "1", "fill": CUE,
        })
    elif day.level == 3:
        ET.SubElement(parent, tag("line"), {
            **common, "data-cue": "slash", "x1": str(x + 2.5), "y1": str(y + cell - 2.5),
            "x2": str(x + cell - 2.5), "y2": str(y + 2.5), "stroke": CUE,
            "stroke-width": "1.8", "stroke-linecap": "round",
        })
    else:
        ET.SubElement(parent, tag("path"), {
            **common, "data-cue": "cross",
            "d": f"M{x + cell / 2} {y + 2.5}V{y + cell - 2.5}M{x + 2.5} {y + cell / 2}H{x + cell - 2.5}",
            "stroke": CUE, "stroke-width": "1.8", "stroke-linecap": "round",
        })


def root_element(width: int, height: int, description: str, title_value: str) -> ET.Element:
    root = ET.Element(tag("svg"), {
        "width": str(width), "height": str(height), "viewBox": f"0 0 {width} {height}", "role": "img",
        "aria-labelledby": "contribution-title contribution-description",
    })
    title = ET.SubElement(root, tag("title"), {"id": "contribution-title"})
    title.text = title_value
    desc = ET.SubElement(root, tag("desc"), {"id": "contribution-description"})
    desc.text = description
    ET.SubElement(root, tag("rect"), {
        "data-testid": "background", "width": "100%", "height": "100%", "fill": BACKGROUND, "rx": "8",
    })
    return root


def render_desktop(grid: Grid) -> ET.Element:
    cell, gap, left, top = 11, 3, 38, 31
    width = max(260, left + len(grid.weeks) * (cell + gap) + 10)
    height = top + 7 * (cell + gap) + 35
    root = root_element(width, height, grid.description, "Brad Groux's contribution activity")
    for week_index, label in grid.month_labels:
        add_text(root, left + week_index * (cell + gap), 17, label, test_id="axis-label")
    for day_index, label in ((1, "Mon"), (3, "Wed"), (5, "Fri")):
        add_text(root, 4, top + day_index * (cell + gap) + 10, label, test_id="axis-label")
    for week_index, week in enumerate(grid.weeks):
        for day_index, day in enumerate(week):
            add_cell(root, left + week_index * (cell + gap), top + day_index * (cell + gap), day, cell)
    summary = ET.SubElement(root, tag("text"), {
        "x": str(left), "y": str(height - 10), "fill": ACCENT, "font-size": "12", "font-family": FONT,
    })
    summary.text = f"{grid.total:,} contributions in the last year"
    return root


def render_mobile(grid: Grid) -> ET.Element:
    cell, gap, left = 11, 3, 43
    band_count = min(3, max(1, len(grid.weeks)))
    columns = max(1, math.ceil(len(grid.weeks) / band_count))
    band_height = 124
    width = min(320, left + columns * (cell + gap) + 10)
    height = 12 + band_count * band_height + 28
    root = root_element(width, height, grid.description, "Brad Groux's mobile contribution activity")
    for band in range(band_count):
        first_week = band * columns
        last_week = min(len(grid.weeks), first_week + columns)
        if first_week >= last_week:
            break
        origin_y = 14 + band * band_height
        add_text(root, 4, origin_y + 12, f"Weeks {first_week + 1}–{last_week}", test_id="axis-label")
        grid_top = origin_y + 20
        for day_index, label in ((1, "M"), (3, "W"), (5, "F")):
            add_text(root, 22, grid_top + day_index * (cell + gap) + 10, label, test_id="axis-label")
        for local_week, week in enumerate(grid.weeks[first_week:last_week]):
            for day_index, day in enumerate(week):
                add_cell(root, left + local_week * (cell + gap), grid_top + day_index * (cell + gap), day, cell)
    summary = ET.SubElement(root, tag("text"), {
        "x": "4", "y": str(height - 10), "fill": ACCENT, "font-size": "12", "font-family": FONT,
    })
    summary.text = f"{grid.total:,} contributions in the last year"
    return root


def write_atomic(root: ET.Element, target: Path) -> None:
    if not target.parent.is_dir():
        raise RenderError(f"output directory does not exist: {target.parent}")
    payload = ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(prefix=f".{target.name}.", dir=target.parent, delete=False) as temporary:
            temporary_path = Path(temporary.name)
            temporary.write(payload)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, target)
    finally:
        if temporary_path and temporary_path.exists():
            temporary_path.unlink()


def main() -> int:
    if len(sys.argv) != 5 or sys.argv[1] not in {"json", "legacy-svg"}:
        print("usage: render-contribution-grid.py (json|legacy-svg) INPUT DESKTOP_SVG MOBILE_SVG", file=sys.stderr)
        return 2
    try:
        source = Path(sys.argv[2])
        grid = load_json(source) if sys.argv[1] == "json" else load_legacy_svg(source)
        write_atomic(render_desktop(grid), Path(sys.argv[3]))
        write_atomic(render_mobile(grid), Path(sys.argv[4]))
    except (OSError, RenderError) as error:
        print(f"contribution grid rejected: {error}", file=sys.stderr)
        return 1
    print(f"rendered accessible contribution grids: {grid.total:,} contributions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
