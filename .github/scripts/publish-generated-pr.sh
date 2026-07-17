#!/usr/bin/env bash
# Publish validated generated files through a dedicated branch and pull request.

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: publish-generated-pr.sh ALLOWED_PATH [...]" >&2
  exit 2
fi

for required_name in \
  PUBLISH_BRANCH \
  PUBLISH_COMMIT_MESSAGE \
  PUBLISH_PR_TITLE \
  PUBLISH_PR_BODY; do
  if [ -z "${!required_name:-}" ]; then
    echo "missing required environment variable: $required_name" >&2
    exit 2
  fi
done

if [[ ! "$PUBLISH_BRANCH" =~ ^automation/[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "publication branch must match automation/[a-z0-9._-]+" >&2
  exit 2
fi

ROOT="$(git rev-parse --show-toplevel)"
GUARD="${PUBLISH_GUARD:-$ROOT/.github/scripts/verify-generated-diff.sh}"
cd "$ROOT"

for allowed_path in "$@"; do
  if [[ "$allowed_path" = /* || "$allowed_path" = *".."* ]]; then
    echo "allowed path must be repository-relative without '..': $allowed_path" >&2
    exit 2
  fi
  if ! git ls-files --error-unmatch -- "$allowed_path" >/dev/null 2>&1; then
    echo "allowed path must already be tracked: $allowed_path" >&2
    exit 2
  fi
done

bash "$GUARD" "$@"

if git diff --quiet HEAD -- "$@"; then
  echo "No generated changes to publish"
  exit 0
fi

git switch -C "$PUBLISH_BRANCH"
git add -- "$@"
bash "$GUARD" "$@"

if git diff --cached --quiet; then
  echo "No generated changes to publish"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git commit -m "$PUBLISH_COMMIT_MESSAGE"

if [ "${PUBLISH_DRY_RUN:-false}" = true ]; then
  echo "Dry run complete; remote publication skipped"
  exit 0
fi

if [ -z "${GITHUB_REPOSITORY:-}" ]; then
  echo "GITHUB_REPOSITORY is required for remote publication" >&2
  exit 2
fi

remote_ref="refs/heads/$PUBLISH_BRANCH"
repository_owner="${GITHUB_REPOSITORY%%/*}"
remote_sha="$(git ls-remote --heads origin "$remote_ref" | awk 'NR == 1 { print $1 }')"
if [ -n "$remote_sha" ]; then
  git push \
    --force-with-lease="$remote_ref:$remote_sha" \
    origin "HEAD:$remote_ref"
else
  git push origin "HEAD:$remote_ref"
fi

pr_number="$(
  gh pr list \
    --repo "$GITHUB_REPOSITORY" \
    --base main \
    --head "$repository_owner:$PUBLISH_BRANCH" \
    --state open \
    --json number \
    --jq '.[0].number // empty'
)"

if [ -n "$pr_number" ]; then
  gh pr edit "$pr_number" \
    --repo "$GITHUB_REPOSITORY" \
    --title "$PUBLISH_PR_TITLE" \
    --body "$PUBLISH_PR_BODY"
else
  gh pr create \
    --repo "$GITHUB_REPOSITORY" \
    --base main \
    --head "$PUBLISH_BRANCH" \
    --title "$PUBLISH_PR_TITLE" \
    --body "$PUBLISH_PR_BODY"
fi
