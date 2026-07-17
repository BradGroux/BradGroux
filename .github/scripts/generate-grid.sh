#!/usr/bin/env bash
# Generate the Tokyo Night contribution grid from a validated GitHub response.

set -euo pipefail

USERNAME="BradGroux"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_FILE="${GRID_OUTPUT_FILE:-$ROOT/contribution-grid.svg}"
MOBILE_OUTPUT_FILE="${GRID_MOBILE_OUTPUT_FILE:-$ROOT/contribution-grid-mobile.svg}"
README_FILE="${README_FILE:-$ROOT/README.md}"
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
QUERY="query{user(login:\"${USERNAME}\"){contributionsCollection{contributionCalendar{totalContributions weeks{contributionDays{contributionCount date}}}}}}"

if [ ! -d "$OUTPUT_DIR" ] || [ ! -d "$(dirname "$MOBILE_OUTPUT_FILE")" ]; then
  echo "Contribution-grid output directory does not exist: $OUTPUT_DIR" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/generate-grid.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
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

TOTAL="$(printf '%s' "$RESPONSE" | jq -r '.data.user.contributionsCollection.contributionCalendar.totalContributions')"
RESPONSE_FILE="$TMP_DIR/response.json"
DESKTOP_CANDIDATE="$TMP_DIR/contribution-grid.svg"
MOBILE_CANDIDATE="$TMP_DIR/contribution-grid-mobile.svg"
README_CANDIDATE="$TMP_DIR/README.md"
printf '%s\n' "$RESPONSE" > "$RESPONSE_FILE"
cp "$README_FILE" "$README_CANDIDATE"

python3 "$ROOT/.github/scripts/render-contribution-grid.py" \
  json "$RESPONSE_FILE" "$DESKTOP_CANDIDATE" "$MOBILE_CANDIDATE"
python3 "$ROOT/.github/scripts/update-readme-activity.py" \
  grid "$RESPONSE_FILE" "$README_CANDIDATE"

chmod 0644 "$DESKTOP_CANDIDATE" "$MOBILE_CANDIDATE" "$README_CANDIDATE"
mv -f "$DESKTOP_CANDIDATE" "$OUTPUT_FILE"
mv -f "$MOBILE_CANDIDATE" "$MOBILE_OUTPUT_FILE"
mv -f "$README_CANDIDATE" "$README_FILE"
echo "Generated accessible desktop and mobile grids, ${TOTAL} contributions"
