#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GENERATOR="$ROOT/.github/scripts/generate-grid.sh"
FIXTURES="$ROOT/.github/tests/grid/fixtures"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${STUB_RESPONSE_FILE:-}" ]; then
  cat "$STUB_RESPONSE_FILE"
  exit 0
fi

echo "request failed for token ${GH_TOKEN:-missing}" >&2
exit 1
STUB
chmod +x "$TMP_DIR/bin/gh"

run_fixture() {
  local fixture="$1"
  (
    cd "$TMP_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      STUB_RESPONSE_FILE="$fixture" \
      GRID_RESPONSE_FILE="$fixture" \
      GRID_OUTPUT_FILE="$TMP_DIR/contribution-grid.svg" \
      GRID_MOBILE_OUTPUT_FILE="$TMP_DIR/contribution-grid-mobile.svg" \
      README_FILE="$TMP_DIR/README.md" \
      bash "$GENERATOR"
  )
}

cp "$ROOT/README.md" "$TMP_DIR/README.md"
run_fixture "$FIXTURES/valid.json"
cp "$TMP_DIR/contribution-grid.svg" "$TMP_DIR/valid-a.svg"
cp "$TMP_DIR/contribution-grid-mobile.svg" "$TMP_DIR/valid-mobile-a.svg"
cp "$TMP_DIR/README.md" "$TMP_DIR/valid-readme-a.md"
run_fixture "$FIXTURES/valid.json"
cp "$TMP_DIR/contribution-grid.svg" "$TMP_DIR/valid-b.svg"
cp "$TMP_DIR/contribution-grid-mobile.svg" "$TMP_DIR/valid-mobile-b.svg"
python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$TMP_DIR/valid-a.svg"
python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$TMP_DIR/valid-mobile-a.svg"
cmp "$TMP_DIR/valid-a.svg" "$TMP_DIR/valid-b.svg"
cmp "$TMP_DIR/valid-mobile-a.svg" "$TMP_DIR/valid-mobile-b.svg"
cmp "$TMP_DIR/valid-readme-a.md" "$TMP_DIR/README.md"
grep -q '>27 contributions in the last year<' "$TMP_DIR/valid-a.svg"
if grep -q 'null' "$TMP_DIR/valid-a.svg"; then
  echo "Valid output unexpectedly contains null" >&2
  exit 1
fi

python3 - "$TMP_DIR/valid-a.svg" "$TMP_DIR/valid-mobile-a.svg" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET


def local_name(tag):
    return tag.rsplit("}", 1)[-1]


def luminance(color):
    channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    channels = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(first, second):
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


for path, mobile in ((sys.argv[1], False), (sys.argv[2], True)):
    root = ET.parse(path).getroot()
    assert root.get("role") == "img"
    labelled_by = root.get("aria-labelledby", "").split()
    assert len(labelled_by) == 2
    ids = {element.get("id") for element in root.iter() if element.get("id")}
    assert set(labelled_by) <= ids
    assert any(local_name(element.tag) == "title" for element in root.iter())
    assert any(local_name(element.tag) == "desc" for element in root.iter())
    assert {element.get("data-level") for element in root.iter()} >= {"0", "1", "2", "3", "4"}
    assert {element.get("data-cue") for element in root.iter() if element.get("data-cue")} >= {"dot", "bar", "slash", "cross"}

    background = next(element.get("fill") for element in root.iter() if element.get("data-testid") == "background")
    label_colors = {element.get("fill") for element in root.iter() if element.get("data-testid") == "axis-label"}
    assert label_colors and all(contrast(color, background) >= 4.5 for color in label_colors)
    for cue in (element for element in root.iter() if element.get("data-cue")):
        parent_fill = cue.get("data-cell-fill")
        assert contrast(cue.get("fill") or cue.get("stroke"), parent_fill) >= 3

    if mobile:
        view_box = [float(value) for value in root.get("viewBox").split()]
        assert view_box[2] <= 320
        label_sizes = [float(re.sub("[^0-9.]", "", element.get("font-size"))) for element in root.iter() if element.get("data-testid") == "axis-label"]
        assert label_sizes and min(label_sizes) >= 12
PY

grep -q '<!-- contribution-summary:start -->' "$TMP_DIR/README.md"
grep -q '\*\*Contribution activity:\*\* 27 contributions in the last year across 4 active days; peak day: 12 contributions on January 5, 2026.' "$TMP_DIR/README.md"
grep -q '<source media="(max-width: 600px)" srcset="./contribution-grid-mobile.svg"' "$TMP_DIR/README.md"
grep -q '<img src="./contribution-grid.svg" alt="" width="100%"' "$TMP_DIR/README.md"

run_fixture "$FIXTURES/zero.json"
cp "$TMP_DIR/contribution-grid.svg" "$TMP_DIR/zero.svg"
python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$TMP_DIR/zero.svg"
grep -q '>0 contributions in the last year<' "$TMP_DIR/zero.svg"

for fixture in graphql-errors null-calendar invalid-day invalid-total malformed; do
  output="$TMP_DIR/contribution-grid.svg"
  mobile_output="$TMP_DIR/contribution-grid-mobile.svg"
  printf 'last-known-good\n' > "$output"
  printf 'last-known-good-mobile\n' > "$mobile_output"
  cp "$ROOT/README.md" "$TMP_DIR/README.md"
  cp "$output" "$TMP_DIR/$fixture.before"
  cp "$mobile_output" "$TMP_DIR/$fixture.mobile.before"
  cp "$TMP_DIR/README.md" "$TMP_DIR/$fixture.readme.before"

  if run_fixture "$FIXTURES/$fixture.json" >"$TMP_DIR/$fixture.stdout" 2>"$TMP_DIR/$fixture.stderr"; then
    echo "Expected $fixture fixture to fail" >&2
    exit 1
  fi

  cmp "$TMP_DIR/$fixture.before" "$output"
  cmp "$TMP_DIR/$fixture.mobile.before" "$mobile_output"
  cmp "$TMP_DIR/$fixture.readme.before" "$TMP_DIR/README.md"
  if ! grep -Eq 'GraphQL|invalid contribution response' "$TMP_DIR/$fixture.stderr"; then
    echo "Expected actionable validation diagnostic for $fixture" >&2
    cat "$TMP_DIR/$fixture.stderr" >&2
    exit 1
  fi
done

printf 'last-known-good\n' > "$TMP_DIR/contribution-grid.svg"
printf 'last-known-good-mobile\n' > "$TMP_DIR/contribution-grid-mobile.svg"
cp "$ROOT/README.md" "$TMP_DIR/README.md"
cp "$TMP_DIR/contribution-grid.svg" "$TMP_DIR/transport.svg.before"
cp "$TMP_DIR/contribution-grid-mobile.svg" "$TMP_DIR/transport.mobile.before"
cp "$TMP_DIR/README.md" "$TMP_DIR/transport.readme.before"
if (
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
    GH_TOKEN='fixture-secret-must-not-leak' \
    GRID_OUTPUT_FILE="$TMP_DIR/contribution-grid.svg" \
    GRID_MOBILE_OUTPUT_FILE="$TMP_DIR/contribution-grid-mobile.svg" \
    README_FILE="$TMP_DIR/README.md" \
    bash "$GENERATOR"
) >"$TMP_DIR/transport.stdout" 2>"$TMP_DIR/transport.stderr"; then
  echo "Expected transport failure" >&2
  exit 1
fi

cmp "$TMP_DIR/transport.svg.before" "$TMP_DIR/contribution-grid.svg"
cmp "$TMP_DIR/transport.mobile.before" "$TMP_DIR/contribution-grid-mobile.svg"
cmp "$TMP_DIR/transport.readme.before" "$TMP_DIR/README.md"
grep -q 'request failed' "$TMP_DIR/transport.stderr"
if grep -q 'fixture-secret-must-not-leak' "$TMP_DIR/transport.stderr"; then
  echo "Transport diagnostic leaked the token" >&2
  exit 1
fi

echo "contribution-grid generator tests passed"
