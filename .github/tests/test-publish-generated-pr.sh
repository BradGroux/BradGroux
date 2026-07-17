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

new_profile_repo() {
  local repo="$1"
  mkdir -p "$repo/assets"
  git -C "$repo" init --quiet
  git -C "$repo" config user.name "Generated Profile Test"
  git -C "$repo" config user.email "generated-profile@example.invalid"
  printf 'stats-old\n' > "$repo/assets/github-stats.svg"
  printf 'grid-old\n' > "$repo/contribution-grid.svg"
  printf 'mobile-old\n' > "$repo/contribution-grid-mobile.svg"
  printf 'readme-old\n' > "$repo/README.md"
  git -C "$repo" add .
  git -C "$repo" commit --quiet -m "profile fixture"
}

publish_profile() {
  local repo="$1"
  (
    cd "$repo"
    PUBLISH_BRANCH="automation/profile-activity" \
      PUBLISH_GUARD="$ROOT/.github/scripts/verify-generated-diff.sh" \
      PUBLISH_COMMIT_MESSAGE="chore: refresh profile activity" \
      PUBLISH_PR_TITLE="Refresh profile activity" \
      PUBLISH_PR_BODY="Validated profile update." \
      PUBLISH_DRY_RUN=true \
      bash "$PUBLISHER" \
        assets/github-stats.svg \
        contribution-grid.svg \
        contribution-grid-mobile.svg \
        README.md
  )
}

no_change_repo="$TMP_DIR/profile-no-change"
new_profile_repo "$no_change_repo"
no_change_output="$(publish_profile "$no_change_repo")"
[[ "$no_change_output" == *"No generated changes to publish"* ]]
test "$(git -C "$no_change_repo" rev-list --count HEAD)" -eq 1

one_change_repo="$TMP_DIR/profile-one-change"
new_profile_repo "$one_change_repo"
printf 'stats-new\n' > "$one_change_repo/assets/github-stats.svg"
publish_profile "$one_change_repo"
test "$(git -C "$one_change_repo" rev-list --count HEAD)" -eq 2
test "$(git -C "$one_change_repo" show --pretty='' --name-only HEAD)" = "assets/github-stats.svg"

both_change_repo="$TMP_DIR/profile-both-change"
new_profile_repo "$both_change_repo"
printf 'stats-new\n' > "$both_change_repo/assets/github-stats.svg"
printf 'grid-new\n' > "$both_change_repo/contribution-grid.svg"
publish_profile "$both_change_repo"
test "$(git -C "$both_change_repo" rev-list --count HEAD)" -eq 2
test "$(git -C "$both_change_repo" show --pretty='' --name-only HEAD | sort)" = $'assets/github-stats.svg\ncontribution-grid.svg'

echo "generated PR publication tests passed"
