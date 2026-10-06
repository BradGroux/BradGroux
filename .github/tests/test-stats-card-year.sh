#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CUSTOMIZER="$ROOT/.github/scripts/set-stats-card-year.py"
FIXTURE="$ROOT/.github/tests/stats-card/fixtures/valid.svg"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

year_candidate="$TMP_DIR/year-candidate.svg"
year_target="$TMP_DIR/year-target.svg"
sed \
  -e 's/Total Commits  (last year) /Total Commits  (2026) /' \
  -e 's/Total Commits (last year):/Total Commits (2026):/' \
  "$FIXTURE" > "$year_candidate"

python3 "$CUSTOMIZER" \
  "$year_candidate" \
  "$year_target" \
  --username BradGroux \
  --year 2026 \
  --contributed-to 16

[[ "$(rg -o 'Total Commits[^<]*(2026)[^<]*' "$year_target" | wc -l | tr -d ' ')" == "2" ]]
[[ "$(rg -o 'Contributed to \(2026\)' "$year_target" | wc -l | tr -d ' ')" == "2" ]]
rg -q 'Contributed to \(2026\): 16</desc>' "$year_target"
rg -Uq 'data-testid="contribs"\s*>16</text>' "$year_target"

if python3 "$CUSTOMIZER" \
  "$FIXTURE" \
  "$TMP_DIR/rejected.svg" \
  --username BradGroux \
  --year 2026 \
  --contributed-to 16 2> "$TMP_DIR/rejection.log"; then
  echo "Expected a candidate without 2026 commit data to be rejected" >&2
  exit 1
fi
rg -q 'candidate must contain two Total Commits \(2026\) labels' "$TMP_DIR/rejection.log"
[[ ! -e "$TMP_DIR/rejected.svg" ]]

echo "calendar-year stats-card tests passed"
