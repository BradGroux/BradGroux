#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBLISHER="$ROOT/.github/scripts/publish-generated-pr.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

new_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init --quiet
  git -C "$repo" config user.name "Generated PR Test"
  git -C "$repo" config user.email "generated-pr@example.invalid"
  printf 'old\n' > "$repo/generated.svg"
  git -C "$repo" add generated.svg
  git -C "$repo" commit --quiet -m "fixture"
}

success_repo="$TMP_DIR/success"
new_repo "$success_repo"
printf 'new\n' > "$success_repo/generated.svg"
(
  cd "$success_repo"
  PUBLISH_BRANCH="automation/test-asset" \
    PUBLISH_GUARD="$ROOT/.github/scripts/verify-generated-diff.sh" \
    PUBLISH_COMMIT_MESSAGE="chore: update test asset" \
    PUBLISH_PR_TITLE="Update test asset" \
    PUBLISH_PR_BODY="Validated test update." \
    PUBLISH_DRY_RUN=true \
    bash "$PUBLISHER" generated.svg
)

test "$(git -C "$success_repo" branch --show-current)" = "automation/test-asset"
test "$(git -C "$success_repo" log -1 --pretty=%s)" = "chore: update test asset"
test -z "$(git -C "$success_repo" status --short)"
test "$(git -C "$success_repo" show --pretty='' --name-only HEAD)" = "generated.svg"

unexpected_repo="$TMP_DIR/unexpected"
new_repo "$unexpected_repo"
printf 'new\n' > "$unexpected_repo/generated.svg"
printf 'unexpected\n' > "$unexpected_repo/other.txt"
if output=$(
  cd "$unexpected_repo"
  PUBLISH_BRANCH="automation/test-asset" \
    PUBLISH_GUARD="$ROOT/.github/scripts/verify-generated-diff.sh" \
    PUBLISH_COMMIT_MESSAGE="chore: update test asset" \
    PUBLISH_PR_TITLE="Update test asset" \
    PUBLISH_PR_BODY="Validated test update." \
    PUBLISH_DRY_RUN=true \
    bash "$PUBLISHER" generated.svg 2>&1
); then
  echo "Expected unexpected-path rejection" >&2
  exit 1
fi
if [[ "$output" != *"other.txt"* ]]; then
  echo "Unexpected-path rejection did not name other.txt" >&2
  exit 1
fi

invalid_repo="$TMP_DIR/invalid-branch"
new_repo "$invalid_repo"
printf 'new\n' > "$invalid_repo/generated.svg"
if (
  cd "$invalid_repo"
  PUBLISH_BRANCH="main" \
    PUBLISH_GUARD="$ROOT/.github/scripts/verify-generated-diff.sh" \
    PUBLISH_COMMIT_MESSAGE="chore: update test asset" \
    PUBLISH_PR_TITLE="Update test asset" \
    PUBLISH_PR_BODY="Validated test update." \
    PUBLISH_DRY_RUN=true \
    bash "$PUBLISHER" generated.svg
) >/dev/null 2>&1; then
  echo "Expected non-automation branch rejection" >&2
  exit 1
fi

echo "generated PR publication tests passed"
