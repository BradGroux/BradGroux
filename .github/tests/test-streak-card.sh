#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/.github/scripts/install-streak-card.py"
FIXTURES="$ROOT/.github/tests/streak-card/fixtures"
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

trailing_candidate="$TMP_DIR/trailing-candidate.svg"
trailing_target="$TMP_DIR/trailing-target.svg"
sed 's#</text>#</text>   #' "$FIXTURES/valid.svg" > "$trailing_candidate"
python3 "$VALIDATOR" "$trailing_candidate" "$trailing_target"
if grep -n '[[:blank:]]$' "$trailing_target"; then
  echo "Installed card contains trailing whitespace" >&2
  exit 1
fi

assert_rejected_without_replacement \
  "$FIXTURES/error-marker.svg" \
  "upstream-error" \
  "upstream error marker found"
assert_rejected_without_replacement \
  "$FIXTURES/missing-label.svg" \
  "missing-label" \
  "missing expected labels"
assert_rejected_without_replacement \
  "$FIXTURES/malformed.svg" \
  "malformed" \
  "invalid SVG XML"

echo "streak-card validation tests passed"
