#!/bin/bash
# Claude Code statusline script
# version: 0.2.7
# Displays: model name | 5-hour usage | 7-day usage | context bar
# Records: one line of rate-limit usage per refresh (see "Record usage" below)

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

# --- Record usage (state dir: platform root, else XDG state) ---
if [ -n "${AGENT_PLATFORM_ROOT:-}" ]; then
    STATE_DIR="${AGENT_PLATFORM_ROOT%/}/state/statusline"
else
    STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code-statusline"
fi
USAGE_LOG="$STATE_DIR/rate-limits.jsonl"

if mkdir -p "$STATE_DIR" 2>/dev/null; then
    # Start a new log when the month changes. Runs in the background so the display never
    # waits; the script does nothing when the mark already names this month.
    if [ "$(cat "$STATE_DIR/.rate-limits.month" 2>/dev/null)" != "$(date +%Y-%m)" ]; then
        bash "$(dirname "${BASH_SOURCE[0]}")/rotate-usage-log.sh" "$STATE_DIR" >/dev/null 2>&1 &
    fi

    # Only when Claude Code sends rate limits. Spaces after ":" and "," keep the line in the
    # form rotate-usage-log.sh matches on.
    if [ -n "$FIVE_H" ]; then
        # "~/.claude-work" -> "work", "~/.claude" or unset -> "personal"
        ACCOUNT_ID=$(basename "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" | sed 's/^\.claude-//; s/^\.claude$/personal/')
        [ -z "$ACCOUNT_ID" ] && ACCOUNT_ID="personal"
        printf '%s' "$input" | jq -r \
            --argjson now "$(date +%s)" --arg iso "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --arg account "$ACCOUNT_ID" --argjson ctx "$CTX_PCT" '
            def pair(key; value): "\"\(key)\": \(value | tojson)";
            [ pair("timestamp"; $now),
              pair("datetime"; $iso),
              pair("session_id"; .session_id // ""),
              pair("account_id"; $account),
              pair("model"; .model.display_name // "?"),
              pair("five_hour_pct"; .rate_limits.five_hour.used_percentage),
              pair("five_hour_resets_at"; .rate_limits.five_hour.resets_at // 0),
              pair("seven_day_pct"; .rate_limits.seven_day.used_percentage // 0),
              pair("seven_day_resets_at"; .rate_limits.seven_day.resets_at // 0),
              pair("input_tokens"; .context_window.total_input_tokens // 0),
              pair("output_tokens"; .context_window.total_output_tokens // 0),
              pair("context_pct"; $ctx)
            ] | "{" + join(", ") + "}"' >> "$USAGE_LOG" 2>/dev/null
    fi

    # Which Claude session runs in which tmux session: several tabs can share a directory,
    # so the newest transcript alone does not tell them apart.
    TMUX_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
    SESSION_ID=$(printf '%s' "$input" | jq -r '.session_id // ""')
    if [ -n "$TMUX_SESSION" ] && [ -n "$SESSION_ID" ]; then
        mkdir -p "$STATE_DIR/tmux-session-map" 2>/dev/null
        printf '%s' "$SESSION_ID" > "$STATE_DIR/tmux-session-map/$TMUX_SESSION" 2>/dev/null
    fi
fi
