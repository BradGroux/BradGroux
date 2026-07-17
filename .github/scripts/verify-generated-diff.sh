#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: verify-generated-diff.sh ALLOWED_PATH [...]" >&2
  exit 2
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

unexpected=0
while IFS= read -r -d '' changed_path; do
  allowed=false
  for allowed_path in "$@"; do
    if [ "$changed_path" = "$allowed_path" ]; then
      allowed=true
      break
    fi
  done

  if [ "$allowed" != true ]; then
    echo "unexpected generated-workflow path: $changed_path" >&2
    unexpected=1
  fi
done < <(
  git diff --name-only -z HEAD --
  git ls-files --others --exclude-standard -z
)

if [ "$unexpected" -ne 0 ]; then
  exit 1
fi

echo "generated workflow changed only allow-listed paths"
