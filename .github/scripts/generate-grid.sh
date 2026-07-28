#!/bin/bash
# Generate a numbered Tokyo Night purple contribution grid SVG.
# Runs via GitHub Actions with GITHUB_TOKEN.

set -euo pipefail

BG="#1a1b27"
EMPTY="#2a2e3f"
L1="#3b1f7e"
L2="#5b2fb5"
L3="#7c3aed"
L4="#8b5cf6"
LABEL="#545c7e"
ACCENT="#70a5fd"
TEXT_LIGHT="#f8fafc"
TEXT_DARK="#1a1b27"

USERNAME="BradGroux"

QUERY="query{user(login:\"${USERNAME}\"){contributionsCollection{contributionCalendar{totalContributions weeks{contributionDays{contributionCount contributionLevel date}}}}}}"

if [[ -n "${CONTRIBUTION_DATA_FILE:-}" ]]; then
  if [[ ! -f "$CONTRIBUTION_DATA_FILE" ]]; then
    echo "Contribution fixture not found: $CONTRIBUTION_DATA_FILE" >&2
    exit 1
  fi
  RESPONSE=$(jq -c '.' "$CONTRIBUTION_DATA_FILE")
elif ! RESPONSE=$(gh api graphql -f query="$QUERY"); then
  echo "Failed to fetch contribution data" >&2
  exit 1
fi

CALENDAR=$(printf '%s' "$RESPONSE" | jq -e '.data.user.contributionsCollection.contributionCalendar')
WEEKS=$(printf '%s' "$CALENDAR" | jq -c '.weeks')
NUM_WEEKS=$(printf '%s' "$WEEKS" | jq 'length')
TOTAL=$(printf '%s' "$CALENDAR" | jq '.totalContributions')

if [[ "$NUM_WEEKS" -eq 0 ]]; then
  echo "Contribution calendar returned no weeks" >&2
  exit 1
fi

CELL=28
GAP=6
STEP=$((CELL + GAP))
PAD_X=24
PAD_Y=24
HEADER_HEIGHT=60
MONTH_HEADER_HEIGHT=20
PANEL_GAP=36
FOOTER_HEIGHT=44
WEEKDAY_LABEL_WIDTH=28
WEEKS_PER_ROW="${WEEKS_PER_ROW:-27}"

if ! [[ "$WEEKS_PER_ROW" =~ ^[1-9][0-9]*$ ]]; then
  echo "WEEKS_PER_ROW must be a positive integer" >&2
  exit 1
fi

PANEL_ROWS=$(((NUM_WEEKS + WEEKS_PER_ROW - 1) / WEEKS_PER_ROW))
MAX_COLUMNS=$NUM_WEEKS
if [[ "$MAX_COLUMNS" -gt "$WEEKS_PER_ROW" ]]; then
  MAX_COLUMNS=$WEEKS_PER_ROW
fi

GRID_START_X=$((PAD_X + WEEKDAY_LABEL_WIDTH))
FIRST_GRID_START_Y=$((HEADER_HEIGHT + PAD_Y + MONTH_HEADER_HEIGHT))
GRID_WIDTH=$((MAX_COLUMNS * STEP))
GRID_HEIGHT=$((7 * STEP))
WIDTH=$((GRID_START_X + GRID_WIDTH + PAD_X))
HEIGHT=$((
  HEADER_HEIGHT
    + PAD_Y
    + PANEL_ROWS * (MONTH_HEADER_HEIGHT + GRID_HEIGHT)
    + (PANEL_ROWS - 1) * PANEL_GAP
    + FOOTER_HEIGHT
))

if [[ "$WIDTH" -lt 700 ]]; then
  WIDTH=700
fi

MONTHS=("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
DAY_LABELS=("" "Mon" "" "Wed" "" "Fri" "")

SVG="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${WIDTH}\" height=\"${HEIGHT}\" viewBox=\"0 0 ${WIDTH} ${HEIGHT}\" role=\"img\" aria-labelledby=\"grid-title\">"
SVG+="<title id=\"grid-title\">${USERNAME} contribution calendar: ${TOTAL} contributions in the last year</title>"
SVG+="<style>.t{font:600 14px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}.b{font:500 11px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}</style>"
SVG+="<rect width=\"${WIDTH}\" height=\"${HEIGHT}\" fill=\"${BG}\" rx=\"8\"/>"
SVG+="<rect width=\"${WIDTH}\" height=\"3\" fill=\"${L4}\" rx=\"8\"/>"
SVG+="<circle cx=\"$((PAD_X + 8))\" cy=\"28\" r=\"5\" fill=\"${L4}\" opacity=\".2\"/>"
SVG+="<circle cx=\"$((PAD_X + 8))\" cy=\"28\" r=\"2.5\" fill=\"${L4}\"/>"
SVG+="<text x=\"$((PAD_X + 18))\" y=\"32\" class=\"t\" fill=\"${ACCENT}\">Contributions</text>"

BADGE_WIDTH=170
BADGE_X=$((WIDTH - PAD_X - BADGE_WIDTH))
SVG+="<rect x=\"${BADGE_X}\" y=\"14\" width=\"${BADGE_WIDTH}\" height=\"22\" rx=\"11\" fill=\"${L4}\" opacity=\".16\"/>"
SVG+="<text x=\"$((BADGE_X + BADGE_WIDTH / 2))\" y=\"29\" text-anchor=\"middle\" class=\"b\" fill=\"${L4}\">${TOTAL} contributions</text>"
SVG+="<line x1=\"${PAD_X}\" y1=\"${HEADER_HEIGHT}\" x2=\"$((WIDTH - PAD_X))\" y2=\"${HEADER_HEIGHT}\" stroke=\"${EMPTY}\" stroke-width=\".5\"/>"

for ((panel = 0; panel < PANEL_ROWS; panel++)); do
  PANEL_GRID_START_Y=$((
    FIRST_GRID_START_Y
      + panel * (MONTH_HEADER_HEIGHT + GRID_HEIGHT + PANEL_GAP)
  ))
  for d in 1 3 5; do
    Y=$((PANEL_GRID_START_Y + d * STEP + CELL / 2 + 4))
    SVG+="<text x=\"$((GRID_START_X - 10))\" y=\"${Y}\" text-anchor=\"end\" fill=\"${LABEL}\" font-size=\"11\" font-family=\"-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif\">${DAY_LABELS[$d]}</text>"
  done
done

LAST_MONTH=""
LAST_PANEL=-1

for ((w = 0; w < NUM_WEEKS; w++)); do
  PANEL=$((w / WEEKS_PER_ROW))
  COLUMN=$((w % WEEKS_PER_ROW))
  GRID_START_Y=$((
    FIRST_GRID_START_Y
      + PANEL * (MONTH_HEADER_HEIGHT + GRID_HEIGHT + PANEL_GAP)
  ))

  if [[ "$PANEL" -ne "$LAST_PANEL" ]]; then
    LAST_MONTH=""
    LAST_PANEL=$PANEL
  fi

  DAYS=$(printf '%s' "$WEEKS" | jq -c ".[$w].contributionDays")
  NUM_DAYS=$(printf '%s' "$DAYS" | jq 'length')
  FIRST_DATE=$(printf '%s' "$DAYS" | jq -r '.[0].date')
  MONTH_NUM=$(printf '%s' "$FIRST_DATE" | cut -d'-' -f2)
  MONTH_IDX=$((10#$MONTH_NUM - 1))
  MONTH_NAME="${MONTHS[$MONTH_IDX]}"

  if [[ "$MONTH_NAME" != "$LAST_MONTH" ]]; then
    MX=$((GRID_START_X + COLUMN * STEP))
    SVG+="<text x=\"${MX}\" y=\"$((GRID_START_Y - 10))\" fill=\"${LABEL}\" font-size=\"10\" font-family=\"-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif\">${MONTH_NAME}</text>"
    LAST_MONTH="$MONTH_NAME"
  fi

  for ((d = 0; d < NUM_DAYS; d++)); do
    COUNT=$(printf '%s' "$DAYS" | jq ".[$d].contributionCount")
    LEVEL=$(printf '%s' "$DAYS" | jq -r ".[$d].contributionLevel // empty")
    DATE=$(printf '%s' "$DAYS" | jq -r ".[$d].date")

    case "$LEVEL" in
      NONE) COLOR="$EMPTY" ;;
      FIRST_QUARTILE) COLOR="$L1" ;;
      SECOND_QUARTILE) COLOR="$L2" ;;
      THIRD_QUARTILE) COLOR="$L3" ;;
      FOURTH_QUARTILE) COLOR="$L4" ;;
      *)
        if [[ "$COUNT" -eq 0 ]]; then
          COLOR="$EMPTY"
        elif [[ "$COUNT" -le 3 ]]; then
          COLOR="$L1"
        elif [[ "$COUNT" -le 6 ]]; then
          COLOR="$L2"
        elif [[ "$COUNT" -le 9 ]]; then
          COLOR="$L3"
        else
          COLOR="$L4"
        fi
        ;;
    esac

    X=$((GRID_START_X + COLUMN * STEP))
    Y=$((GRID_START_Y + d * STEP))
    SVG+="<rect x=\"${X}\" y=\"${Y}\" width=\"${CELL}\" height=\"${CELL}\" rx=\"3\" fill=\"${COLOR}\"><title>${DATE}: ${COUNT} contributions</title></rect>"

    DIGITS=${#COUNT}
    if [[ "$DIGITS" -le 1 ]]; then
      FONT_SIZE="17.36"
    elif [[ "$DIGITS" -eq 2 ]]; then
      FONT_SIZE="16.24"
    elif [[ "$DIGITS" -eq 3 ]]; then
      FONT_SIZE="14"
    elif [[ "$DIGITS" -eq 4 ]]; then
      FONT_SIZE="11.76"
    else
      FONT_SIZE="10.5"
    fi

    if [[ "$COUNT" -eq 0 ]]; then
      TEXT_COLOR="$LABEL"
      OPACITY=".65"
    elif [[ "$COLOR" == "$L4" ]]; then
      TEXT_COLOR="$TEXT_DARK"
      OPACITY="1"
    else
      TEXT_COLOR="$TEXT_LIGHT"
      OPACITY="1"
    fi

    SVG+="<text x=\"$((X + CELL / 2))\" y=\"$((Y + CELL / 2 + 3))\" text-anchor=\"middle\" font-family=\"monospace\" font-size=\"${FONT_SIZE}\" font-weight=\"700\" fill=\"${TEXT_COLOR}\" opacity=\"${OPACITY}\" pointer-events=\"none\">${COUNT}</text>"
  done
done

LEGEND_X=$GRID_START_X
LAST_GRID_START_Y=$((
  FIRST_GRID_START_Y
    + (PANEL_ROWS - 1) * (MONTH_HEADER_HEIGHT + GRID_HEIGHT + PANEL_GAP)
))
LEGEND_Y=$((LAST_GRID_START_Y + GRID_HEIGHT + 28))
LEGEND_COLORS=("$EMPTY" "$L1" "$L2" "$L3" "$L4")
SVG+="<text x=\"${LEGEND_X}\" y=\"${LEGEND_Y}\" fill=\"${LABEL}\" font-size=\"11\" font-family=\"-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif\">Less</text>"

for ((i = 0; i < ${#LEGEND_COLORS[@]}; i++)); do
  LX=$((LEGEND_X + 36 + i * (CELL + 3)))
  SVG+="<rect x=\"${LX}\" y=\"$((LEGEND_Y - 10))\" width=\"$((CELL - 2))\" height=\"$((CELL - 2))\" rx=\"3\" fill=\"${LEGEND_COLORS[$i]}\"/>"
done

MORE_X=$((LEGEND_X + 36 + 5 * (CELL + 3) + 6))
SVG+="<text x=\"${MORE_X}\" y=\"${LEGEND_Y}\" fill=\"${LABEL}\" font-size=\"11\" font-family=\"-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif\">More</text>"
SVG+="</svg>"

printf '%s\n' "$SVG" > contribution-grid.svg
echo "Generated: ${WIDTH}x${HEIGHT}, ${TOTAL} contributions"
