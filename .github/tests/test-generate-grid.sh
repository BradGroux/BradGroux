#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GENERATOR="$ROOT/.github/scripts/generate-grid.sh"
FIXTURES="$ROOT/.github/tests/grid/fixtures"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${STUB_RESPONSE_FILE:-}" ]; then
  cat "$STUB_RESPONSE_FILE"
  exit 0
fi

echo "request failed for token ${GH_TOKEN:-missing}" >&2
exit 1
STUB
chmod +x "$TMP_DIR/bin/gh"

run_fixture() {
  local fixture="$1"
  (
    cd "$TMP_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      STUB_RESPONSE_FILE="$fixture" \
      GRID_RESPONSE_FILE="$fixture" \
      GRID_OUTPUT_FILE="$TMP_DIR/contribution-grid.svg" \
      bash "$GENERATOR"
  )
}

run_fixture "$FIXTURES/valid.json"
cp "$TMP_DIR/contribution-grid.svg" "$TMP_DIR/valid-a.svg"
run_fixture "$FIXTURES/valid.json"
cp "$TMP_DIR/contribution-grid.svg" "$TMP_DIR/valid-b.svg"
python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$TMP_DIR/valid-a.svg"
cmp "$TMP_DIR/valid-a.svg" "$TMP_DIR/valid-b.svg"
grep -q '>10 contributions in the last year<' "$TMP_DIR/valid-a.svg"
if grep -q 'null' "$TMP_DIR/valid-a.svg"; then
  echo "Valid output unexpectedly contains null" >&2
  exit 1
fi

run_fixture "$FIXTURES/zero.json"
cp "$TMP_DIR/contribution-grid.svg" "$TMP_DIR/zero.svg"
python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$TMP_DIR/zero.svg"
grep -q '>0 contributions in the last year<' "$TMP_DIR/zero.svg"

for fixture in graphql-errors null-calendar invalid-day malformed; do
  output="$TMP_DIR/contribution-grid.svg"
  printf 'last-known-good\n' > "$output"
  cp "$output" "$TMP_DIR/$fixture.before"

  if run_fixture "$FIXTURES/$fixture.json" >"$TMP_DIR/$fixture.stdout" 2>"$TMP_DIR/$fixture.stderr"; then
    echo "Expected $fixture fixture to fail" >&2
    exit 1
  fi

  cmp "$TMP_DIR/$fixture.before" "$output"
  if ! grep -Eq 'GraphQL|invalid contribution response' "$TMP_DIR/$fixture.stderr"; then
    echo "Expected actionable validation diagnostic for $fixture" >&2
    cat "$TMP_DIR/$fixture.stderr" >&2
    exit 1
  fi
done

printf 'last-known-good\n' > "$TMP_DIR/contribution-grid.svg"
cp "$TMP_DIR/contribution-grid.svg" "$TMP_DIR/transport.svg.before"
if (
  cd "$TMP_DIR"
  PATH="$TMP_DIR/bin:$PATH" \
    GH_TOKEN='fixture-secret-must-not-leak' \
    GRID_OUTPUT_FILE="$TMP_DIR/contribution-grid.svg" \
    bash "$GENERATOR"
) >"$TMP_DIR/transport.stdout" 2>"$TMP_DIR/transport.stderr"; then
  echo "Expected transport failure" >&2
  exit 1
fi

cmp "$TMP_DIR/transport.svg.before" "$TMP_DIR/contribution-grid.svg"
grep -q 'request failed' "$TMP_DIR/transport.stderr"
if grep -q 'fixture-secret-must-not-leak' "$TMP_DIR/transport.stderr"; then
  echo "Transport diagnostic leaked the token" >&2
  exit 1
fi

echo "contribution-grid generator tests passed"
