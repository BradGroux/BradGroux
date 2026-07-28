#!/bin/bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_DIR=$(mktemp -d)

cleanup() {
  rm -f "$TEST_DIR/contribution-grid.svg"
  rmdir "$TEST_DIR"
}
trap cleanup EXIT

(
  cd "$TEST_DIR"
  WEEKS_PER_ROW=1 \
  CONTRIBUTION_DATA_FILE="$REPO_ROOT/.github/tests/contribution-grid/fixture.json" \
    bash "$REPO_ROOT/.github/scripts/generate-grid.sh"
)

python3 \
  "$REPO_ROOT/.github/tests/validate-contribution-grid.py" \
  "$TEST_DIR/contribution-grid.svg"
