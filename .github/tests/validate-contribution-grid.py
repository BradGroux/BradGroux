#!/usr/bin/env python3

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


if len(sys.argv) != 2:
    fail("usage: validate-contribution-grid.py <contribution-grid.svg>")

svg_path = Path(sys.argv[1])
root = ET.parse(svg_path).getroot()
namespace = {"svg": "http://www.w3.org/2000/svg"}

if root.attrib.get("width") != "700" or root.attrib.get("height") != "366":
    fail(f"unexpected fixture dimensions: {root.attrib}")

day_rects = [
    rect
    for rect in root.findall("svg:rect", namespace)
    if rect.attrib.get("width") == "28" and rect.attrib.get("height") == "28"
]
if len(day_rects) != 14:
    fail(f"expected 14 day cells, found {len(day_rects)}")

expected_counts = [
    "0",
    "1",
    "9",
    "10",
    "99",
    "100",
    "999",
    "1000",
    "42",
    "7",
    "3",
    "15",
    "250",
    "5",
]
count_texts = [
    text.text
    for text in root.findall("svg:text", namespace)
    if text.attrib.get("font-family") == "monospace"
]
if count_texts != expected_counts:
    fail(f"unexpected count labels: {count_texts}")

font_sizes = {
    text.text: text.attrib.get("font-size")
    for text in root.findall("svg:text", namespace)
    if text.attrib.get("font-family") == "monospace"
}
for count, expected_size in {
    "1": "17.36",
    "10": "16.24",
    "100": "14",
    "1000": "11.76",
}.items():
    if font_sizes.get(count) != expected_size:
        fail(f"unexpected font size for {count}: {font_sizes.get(count)}")

expected_colors = {"#2a2e3f", "#3b1f7e", "#5b2fb5", "#7c3aed", "#8b5cf6"}
actual_colors = {rect.attrib.get("fill") for rect in day_rects}
if actual_colors != expected_colors:
    fail(f"unexpected day-cell palette: {actual_colors}")

titles = root.findall(".//svg:rect/svg:title", namespace)
if len(titles) != 14:
    fail(f"expected 14 hover titles, found {len(titles)}")

all_text = " ".join(text.text or "" for text in root.findall("svg:text", namespace))
for expected in ("Contributions", "1234 contributions", "Less", "More", "Mon", "Wed", "Fri"):
    if expected not in all_text:
        fail(f"missing visible label: {expected}")

print("Contribution grid SVG validation passed")
