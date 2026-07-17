#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPDATER="$ROOT/.github/scripts/update-readme-activity.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp "$ROOT/README.md" "$TMP_DIR/README.md"
cp "$TMP_DIR/README.md" "$TMP_DIR/before.md"

python3 "$UPDATER" stats "$ROOT/.github/tests/stats-card/fixtures/valid.svg" "$TMP_DIR/README.md"
grep -q '<strong>GitHub stats:</strong> 829 stars · 841 commits in the last year · 590 pull requests · 736 issues · contributions to 10 repositories in the last year.' "$TMP_DIR/README.md"

cp "$TMP_DIR/README.md" "$TMP_DIR/after-valid.md"
if python3 "$UPDATER" stats "$ROOT/.github/tests/stats-card/fixtures/missing-stats.svg" "$TMP_DIR/README.md" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo "Expected incomplete stats card to fail" >&2
  exit 1
fi
cmp "$TMP_DIR/after-valid.md" "$TMP_DIR/README.md"
grep -q 'missing expected stats' "$TMP_DIR/stderr"

cp "$ROOT/README.md" "$TMP_DIR/duplicate.md"
sed -n '/<!-- github-stats-summary:start -->/,/<!-- github-stats-summary:end -->/p' "$ROOT/README.md" >> "$TMP_DIR/duplicate.md"
if python3 "$UPDATER" stats "$ROOT/.github/tests/stats-card/fixtures/valid.svg" "$TMP_DIR/duplicate.md" >/dev/null 2>&1; then
  echo "Expected duplicate README markers to fail" >&2
  exit 1
fi

echo "README activity summary tests passed"
