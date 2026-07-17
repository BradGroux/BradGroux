#!/usr/bin/env bash
# Run the repository's required pull-request validation checks.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

bash .github/tests/test-stats-card.sh
bash .github/tests/test-generated-diff.sh
bash .github/tests/test-generate-grid.sh
bash .github/tests/test-update-readme-activity.sh
python3 .github/tests/test-docs-navigation.py
bash .github/tests/test-publish-generated-pr.sh

while IFS= read -r script; do
  bash -n "$script"
done < <(rg --files .github | rg '\.sh$' | sort)

ruby -e '
  require "yaml"
  ARGV.each { |path| YAML.parse_file(path) }
' .github/workflows/*.yml .github/dependabot.yml

ruby -e '
  Dir[".github/workflows/*.{yml,yaml}"].each do |file|
    File.readlines(file).each_with_index do |line, index|
      next unless line =~ /uses:\s*([^\s#]+)/
      abort "#{file}:#{index + 1}: mutable action ref #{$1}" unless $1.match?(/@[0-9a-f]{40}$/)
    end
  end
'

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET

for path in (
    Path("assets/github-stats.svg"),
    Path("contribution-grid.svg"),
    Path("contribution-grid-mobile.svg"),
):
    root = ET.parse(path).getroot()
    if root.tag.rsplit("}", 1)[-1] != "svg":
        raise SystemExit(f"{path}: root element must be svg")
    labels = root.get("aria-labelledby", "").split()
    ids = {element.get("id") for element in root.iter() if element.get("id")}
    if len(labels) != 2 or not set(labels) <= ids:
        raise SystemExit(f"{path}: root must reference a title and description")
PY

if rg -n -i 'something went wrong|cannot read properties of undefined|github-readme-stats error' assets/github-stats.svg; then
  echo "Committed stats card contains an upstream error marker" >&2
  exit 1
fi

echo "repository validation passed"
