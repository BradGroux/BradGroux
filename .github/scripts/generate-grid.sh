#!/bin/bash
# Generate Tokyo Night themed contribution grid SVG
# Runs via GitHub Actions with GITHUB_TOKEN

set -euo pipefail

BG="#1a1b27"
EMPTY="#2a2e3f"
L1="#3b1f7e"
L2="#5b2fb5"
L3="#7c3aed"
L4="#8b5cf6"

USERNAME="BradGroux"

QUERY="query{user(login:\"${USERNAME}\"){contributionsCollection{contributionCalendar{totalContributions weeks{contributionDays{contributionCount date}}}}}}"

RESPONSE=$(gh api graphql -f query="$QUERY" 2>/dev/null)

if [ -z "$RESPONSE" ]; then
  echo "Failed to fetch contribution data"
  exit 1
fi

WEEKS=$(echo "$RESPONSE" | jq '.data.user.contributionsCollection.contributionCalendar.weeks')
NUM_WEEKS=$(echo "$WEEKS" | jq 'length')
TOTAL=$(echo "$RESPONSE" | jq '.data.user.contributionsCollection.contributionCalendar.totalContributions')

CELL=11
GAP=3
MARGIN_LEFT=30
MARGIN_TOP=25
WIDTH=$((MARGIN_LEFT + NUM_WEEKS * (CELL + GAP) + 10))
HEIGHT=$((MARGIN_TOP + 7 * (CELL + GAP) + 30))

MONTHS=("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
DAY_LABELS=("" "Mon" "" "Wed" "" "Fri" "")

SVG="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${WIDTH}\" height=\"${HEIGHT}\">"
SVG+="<rect width=\"100%\" height=\"100%\" fill=\"${BG}\" rx=\"6\"/>"

for d in 1 3 5; do
  Y=$((MARGIN_TOP + d * (CELL + GAP) + 9))
  SVG+="<text x=\"2\" y=\"${Y}\" fill=\"#545c7e\" font-size=\"9\" font-family=\"-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif\">${DAY_LABELS[$d]}</text>"
done

LAST_MONTH=""

for ((w=0; w<NUM_WEEKS; w++)); do
  DAYS=$(echo "$WEEKS" | jq ".[$w].contributionDays")
  NUM_DAYS=$(echo "$DAYS" | jq 'length')

  for ((d=0; d<NUM_DAYS; d++)); do
    COUNT=$(echo "$DAYS" | jq ".[$d].contributionCount")
    DATE=$(echo "$DAYS" | jq -r ".[$d].date")
    MONTH_NUM=$(echo "$DATE" | cut -d'-' -f2)
    MONTH_IDX=$((10#$MONTH_NUM - 1))
    MONTH_NAME="${MONTHS[$MONTH_IDX]}"

    if [ "$MONTH_NAME" != "$LAST_MONTH" ] && { [ "$d" -eq 0 ] || [ "$(echo "$DATE" | cut -d'-' -f3)" -le "07" ]; }; then
      if [ "$MONTH_NAME" != "$LAST_MONTH" ]; then
        MX=$((MARGIN_LEFT + w * (CELL + GAP)))
        SVG+="<text x=\"${MX}\" y=\"14\" fill=\"#545c7e\" font-size=\"9\" font-family=\"-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif\">${MONTH_NAME}</text>"
        LAST_MONTH="$MONTH_NAME"
      fi
    fi

    if [ "$COUNT" -eq 0 ]; then
      COLOR="$EMPTY"
    elif [ "$COUNT" -le 3 ]; then
      COLOR="$L1"
    elif [ "$COUNT" -le 6 ]; then
      COLOR="$L2"
    elif [ "$COUNT" -le 9 ]; then
      COLOR="$L3"
    else
      COLOR="$L4"
    fi

    X=$((MARGIN_LEFT + w * (CELL + GAP)))
    Y=$((MARGIN_TOP + d * (CELL + GAP)))
    SVG+="<rect x=\"${X}\" y=\"${Y}\" width=\"${CELL}\" height=\"${CELL}\" rx=\"2\" fill=\"${COLOR}\"/>"
  done
done

TY=$((MARGIN_TOP + 7 * (CELL + GAP) + 15))
SVG+="<text x=\"${MARGIN_LEFT}\" y=\"${TY}\" fill=\"#70a5fd\" font-size=\"11\" font-family=\"-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif\">${TOTAL} contributions in the last year</text>"
SVG+="</svg>"

echo "$SVG" > contribution-grid.svg
echo "Generated: ${WIDTH}x${HEIGHT}, ${TOTAL} contributions"
