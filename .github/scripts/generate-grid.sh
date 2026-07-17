#!/usr/bin/env bash
# Generate the Tokyo Night contribution grid from a validated GitHub response.

set -euo pipefail

BG="#1a1b27"
EMPTY="#2a2e3f"
L1="#3b1f7e"
L2="#5b2fb5"
L3="#7c3aed"
L4="#8b5cf6"

USERNAME="BradGroux"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_FILE="${GRID_OUTPUT_FILE:-$ROOT/contribution-grid.svg}"
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
QUERY="query{user(login:\"${USERNAME}\"){contributionsCollection{contributionCalendar{totalContributions weeks{contributionDays{contributionCount date}}}}}}"

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Contribution-grid output directory does not exist: $OUTPUT_DIR" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/generate-grid.XXXXXX")"
TMP_OUTPUT=""
cleanup() {
  rm -rf "$TMP_DIR"
  if [ -n "$TMP_OUTPUT" ] && [ -e "$TMP_OUTPUT" ]; then
    rm -f "$TMP_OUTPUT"
  fi
}
trap cleanup EXIT

if [ -n "${GRID_RESPONSE_FILE:-}" ]; then
  if [ ! -r "$GRID_RESPONSE_FILE" ]; then
    echo "Contribution response fixture is not readable: $GRID_RESPONSE_FILE" >&2
    exit 1
  fi
  RESPONSE="$(<"$GRID_RESPONSE_FILE")"
else
  ERROR_FILE="$TMP_DIR/gh-api.stderr"
  if ! RESPONSE="$(gh api graphql -f query="$QUERY" 2>"$ERROR_FILE")"; then
    DIAGNOSTIC="$(tr '\r\n' '  ' < "$ERROR_FILE" | cut -c1-400)"
    if [ -n "${GH_TOKEN:-}" ]; then
      DIAGNOSTIC="${DIAGNOSTIC//"$GH_TOKEN"/[REDACTED]}"
    fi
    if [ -n "$DIAGNOSTIC" ]; then
      echo "Failed to fetch contribution data: $DIAGNOSTIC" >&2
    else
      echo "Failed to fetch contribution data: gh api graphql exited nonzero" >&2
    fi
    exit 1
  fi
fi

if ! printf '%s' "$RESPONSE" | jq -e . >/dev/null 2>&1; then
  echo "invalid contribution response: expected valid JSON" >&2
  exit 1
fi

if ! printf '%s' "$RESPONSE" | jq -e \
  '(.errors? == null) or ((.errors | type) == "array")' >/dev/null 2>&1; then
  echo "invalid contribution response: GraphQL errors must be an array" >&2
  exit 1
fi

GRAPHQL_ERROR_COUNT="$(printf '%s' "$RESPONSE" | jq '[.errors[]?] | length')"
if [ "$GRAPHQL_ERROR_COUNT" -ne 0 ]; then
  GRAPHQL_ERROR_TYPES="$(
    printf '%s' "$RESPONSE" |
      jq -r '[.errors[]? | if type == "object" then .type // .extensions.type // "unknown" else "unknown" end] | unique | join(", ")' |
      tr -cd '[:alnum:] _.,:-' |
      cut -c1-120
  )"
  echo "GraphQL returned $GRAPHQL_ERROR_COUNT error(s): $GRAPHQL_ERROR_TYPES" >&2
  exit 1
fi

if ! printf '%s' "$RESPONSE" | jq -e '
  def calendar: .data.user.contributionsCollection.contributionCalendar;
  type == "object" and
  (calendar | type) == "object" and
  (calendar.totalContributions | type) == "number" and
  calendar.totalContributions >= 0 and
  calendar.totalContributions == (calendar.totalContributions | floor) and
  (calendar.weeks | type) == "array" and
  all(calendar.weeks[];
    type == "object" and
    (.contributionDays | type) == "array" and
    (.contributionDays | length) <= 7 and
    all(.contributionDays[];
      type == "object" and
      (.contributionCount | type) == "number" and
      .contributionCount >= 0 and
      .contributionCount == (.contributionCount | floor) and
      (.date | type) == "string" and
      (.date | test("^[0-9]{4}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])$"))
    )
  )
' >/dev/null 2>&1; then
  echo "invalid contribution response: required calendar fields or types are missing" >&2
  exit 1
fi

WEEKS="$(printf '%s' "$RESPONSE" | jq -c '.data.user.contributionsCollection.contributionCalendar.weeks')"
NUM_WEEKS="$(printf '%s' "$WEEKS" | jq 'length')"
TOTAL="$(printf '%s' "$RESPONSE" | jq -r '.data.user.contributionsCollection.contributionCalendar.totalContributions')"

CELL=11
GAP=3
MARGIN_LEFT=30
MARGIN_TOP=25
WIDTH=$((MARGIN_LEFT + NUM_WEEKS * (CELL + GAP) + 10))
HEIGHT=$((MARGIN_TOP + 7 * (CELL + GAP) + 30))

MONTHS=("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
DAY_LABELS=("" "Mon" "" "Wed" "" "Fri" "")

SVG="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${WIDTH}\" height=\"${HEIGHT}\">"
SVG+="<rect width=\"100%\" height=\"100%\" fill=\"${BG}\" rx=\"6\"/>"

for d in 1 3 5; do
  Y=$((MARGIN_TOP + d * (CELL + GAP) + 9))
  SVG+="<text x=\"2\" y=\"${Y}\" fill=\"#545c7e\" font-size=\"9\" font-family=\"-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif\">${DAY_LABELS[$d]}</text>"
done

LAST_MONTH=""

for ((w = 0; w < NUM_WEEKS; w++)); do
  DAYS="$(printf '%s' "$WEEKS" | jq -c ".[$w].contributionDays")"
  NUM_DAYS="$(printf '%s' "$DAYS" | jq 'length')"

  for ((d = 0; d < NUM_DAYS; d++)); do
    COUNT="$(printf '%s' "$DAYS" | jq -r ".[$d].contributionCount")"
    DATE="$(printf '%s' "$DAYS" | jq -r ".[$d].date")"
    MONTH_NUM="${DATE:5:2}"
    DAY_NUM="${DATE:8:2}"
    MONTH_IDX=$((10#$MONTH_NUM - 1))
    MONTH_NAME="${MONTHS[$MONTH_IDX]}"

    if [ "$MONTH_NAME" != "$LAST_MONTH" ] && { [ "$d" -eq 0 ] || [ "$DAY_NUM" -le 7 ]; }; then
      MX=$((MARGIN_LEFT + w * (CELL + GAP)))
      SVG+="<text x=\"${MX}\" y=\"14\" fill=\"#545c7e\" font-size=\"9\" font-family=\"-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif\">${MONTH_NAME}</text>"
      LAST_MONTH="$MONTH_NAME"
    fi

    if [ "$COUNT" -eq 0 ]; then
      COLOR="$EMPTY"
    elif [ "$COUNT" -le 3 ]; then
      COLOR="$L1"
    elif [ "$COUNT" -le 6 ]; then
      COLOR="$L2"
    elif [ "$COUNT" -le 9 ]; then
      COLOR="$L3"
    else
      COLOR="$L4"
    fi

    X=$((MARGIN_LEFT + w * (CELL + GAP)))
    Y=$((MARGIN_TOP + d * (CELL + GAP)))
    SVG+="<rect x=\"${X}\" y=\"${Y}\" width=\"${CELL}\" height=\"${CELL}\" rx=\"2\" fill=\"${COLOR}\"/>"
  done
done

TY=$((MARGIN_TOP + 7 * (CELL + GAP) + 15))
SVG+="<text x=\"${MARGIN_LEFT}\" y=\"${TY}\" fill=\"#70a5fd\" font-size=\"11\" font-family=\"-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif\">${TOTAL} contributions in the last year</text>"
SVG+="</svg>"

TMP_OUTPUT="$(mktemp "$OUTPUT_DIR/.contribution-grid.svg.XXXXXX")"
printf '%s\n' "$SVG" > "$TMP_OUTPUT"

if ! python3 - "$TMP_OUTPUT" "$TOTAL" <<'PY'
import sys
import xml.etree.ElementTree as ET

path, total = sys.argv[1:]
try:
    root = ET.parse(path).getroot()
except ET.ParseError as error:
    raise SystemExit(f"invalid generated SVG XML: {error}")

if root.tag.rsplit("}", 1)[-1] != "svg":
    raise SystemExit("invalid generated SVG: root element must be svg")
if not root.get("width") or not root.get("height"):
    raise SystemExit("invalid generated SVG: dimensions are required")
text = " ".join("".join(element.itertext()) for element in root.iter())
if f"{total} contributions in the last year" not in text:
    raise SystemExit("invalid generated SVG: total-contributions summary is missing")
PY
then
  echo "Generated contribution grid failed validation" >&2
  exit 1
fi

chmod 0644 "$TMP_OUTPUT"
mv -f "$TMP_OUTPUT" "$OUTPUT_FILE"
TMP_OUTPUT=""
echo "Generated: ${WIDTH}x${HEIGHT}, ${TOTAL} contributions"
