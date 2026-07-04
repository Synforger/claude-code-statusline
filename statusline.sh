#!/bin/bash
# Claude Code statusline script
# version: 0.1.0
# Displays: model name | 5-hour usage | 7-day usage | context bar

input=$(cat)

# --- Extract display data ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# --- Colors ---
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
DIM='\033[2m'
RESET='\033[0m'

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then echo "$RED"
    elif [ "$pct" -ge 50 ]; then echo "$YELLOW"
    else echo "$GREEN"
    fi
}

# --- Time until 5-hour window reset ---
FIVE_H_REMAINING=""
if [ -n "$FIVE_H_RESET" ]; then
    NOW=$(date +%s)
    DIFF=$(( FIVE_H_RESET - NOW ))
    if [ "$DIFF" -gt 0 ]; then
        HOURS=$(( DIFF / 3600 ))
        MINS=$(( (DIFF % 3600) / 60 ))
        FIVE_H_REMAINING="${HOURS}h${MINS}m"
    else
        FIVE_H_REMAINING="reset soon"
    fi
fi

# --- Build output ---
OUTPUT="${CYAN}[${MODEL}]${RESET}"

if [ -n "$FIVE_H" ]; then
    FIVE_H_INT=$(printf '%.0f' "$FIVE_H")
    FIVE_H_COLOR=$(color_for_pct "$FIVE_H_INT")
    OUTPUT="${OUTPUT} 5h:${FIVE_H_COLOR}${FIVE_H_INT}%${RESET}"
    [ -n "$FIVE_H_REMAINING" ] && OUTPUT="${OUTPUT}${DIM}(${FIVE_H_REMAINING})${RESET}"
fi

if [ -n "$WEEK" ]; then
    WEEK_INT=$(printf '%.0f' "$WEEK")
    WEEK_COLOR=$(color_for_pct "$WEEK_INT")
    OUTPUT="${OUTPUT} 7d:${WEEK_COLOR}${WEEK_INT}%${RESET}"
fi

# Context bar
BAR_WIDTH=8
FILLED=$((CTX_PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"
CTX_COLOR=$(color_for_pct "$CTX_PCT")

OUTPUT="${OUTPUT} ${DIM}ctx:${RESET}${CTX_COLOR}${BAR}${CTX_PCT}%${RESET}"

echo -e "$OUTPUT"
