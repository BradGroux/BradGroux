#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/.github/scripts/install-stats-card.py"
FIXTURES="$ROOT/.github/tests/stats-card/fixtures"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_rejected_without_replacement() {
  local fixture="$1"
  local name="$2"
  local expected_error="$3"
  local target="$TMP_DIR/${name}-target.svg"
  local before="$TMP_DIR/${name}-before.svg"
  local output

  cp "$FIXTURES/valid.svg" "$target"
  cp "$target" "$before"

  if output=$(python3 "$VALIDATOR" "$fixture" "$target" 2>&1); then
    echo "Expected rejection: $name" >&2
    exit 1
  fi

  if [[ "$output" != *"$expected_error"* ]]; then
    echo "Unexpected rejection for $name: $output" >&2
    exit 1
  fi

  cmp "$before" "$target"
}

valid_target="$TMP_DIR/valid-target.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg"><text>sentinel</text></svg>\n' > "$valid_target"
python3 "$VALIDATOR" "$FIXTURES/valid.svg" "$valid_target"
cmp "$FIXTURES/valid.svg" "$valid_target"

missing_title_label="$TMP_DIR/missing-title-label.svg"
sed 's/aria-labelledby="titleId descId"/aria-labelledby="descId"/' "$FIXTURES/valid.svg" > "$missing_title_label"
normalized_target="$TMP_DIR/normalized-target.svg"
python3 "$VALIDATOR" "$missing_title_label" "$normalized_target"
grep -q 'aria-labelledby="titleId descId"' "$normalized_target"

assert_rejected_without_replacement \
  "$FIXTURES/error.svg" \
  "captured-error-card" \
  'root svg must declare role="img"'
assert_rejected_without_replacement \
  "$FIXTURES/error-marker.svg" \
  "error-marker" \
  "upstream error marker found"
assert_rejected_without_replacement \
  "$FIXTURES/missing-stats.svg" \
  "missing-stats" \
  "missing expected stats"
assert_rejected_without_replacement \
  "$FIXTURES/malformed.svg" \
  "malformed" \
  "invalid SVG XML"

echo "stats-card validation tests passed"
