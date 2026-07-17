#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/.github/scripts/verify-generated-diff.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

git -C "$TMP_DIR" init --quiet
git -C "$TMP_DIR" config user.name "Generated Diff Test"
git -C "$TMP_DIR" config user.email "generated-diff@example.invalid"
mkdir -p "$TMP_DIR/assets"
printf 'old\n' > "$TMP_DIR/assets/github-stats.svg"
git -C "$TMP_DIR" add assets/github-stats.svg
git -C "$TMP_DIR" commit --quiet -m "fixture"

printf 'new\n' > "$TMP_DIR/assets/github-stats.svg"
(
  cd "$TMP_DIR"
  bash "$GUARD" assets/github-stats.svg
)

git -C "$TMP_DIR" add assets/github-stats.svg
(
  cd "$TMP_DIR"
  bash "$GUARD" assets/github-stats.svg
)

printf 'unexpected\n' > "$TMP_DIR/unexpected.txt"
if output=$(
  cd "$TMP_DIR"
  bash "$GUARD" assets/github-stats.svg 2>&1
); then
  echo "Expected unexpected path rejection" >&2
  exit 1
fi

if [[ "$output" != *"unexpected.txt"* ]]; then
  echo "Rejection did not identify the unexpected path: $output" >&2
  exit 1
fi

echo "generated diff guard tests passed"
