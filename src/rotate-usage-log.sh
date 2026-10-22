#!/bin/bash
# Starts a new usage log (rate-limits.jsonl) when the month changes. statusline.sh calls it in the background.
#
# The statusline appends one line per refresh and nothing else trims the file, so it grows
# without bound. The reader only needs the latest line per account.
#
# What it does:
#   1. moves the log so far to `rate-limits-<time>.jsonl.gz` (the history is kept)
#   2. copies the latest line of every account that has no line yet into the new log
#      (an account that rests would otherwise show an empty usage)
#   3. writes the month into `.rate-limits.month` (the mark statusline.sh checks)
#
#   rotate-usage-log.sh <state folder>
#   rotate-usage-log.sh --seed <moved log> <new log>      (step 2 only; the tests call it)
#
# Stays in bash like statusline.sh: jq is this project's only dependency, so there is no
# Python to move the logic to. Fails silently: it runs behind the display, and the next
# refresh calls it again.
set -uo pipefail

# Copies, for each account with no line in <log> yet, its latest line from <old>.
# Lines without an "account_id" (written before the field existed) count as one account.
seed_latest_rows() {
    local old="$1" log="$2" key row
    grep -o '"account_id": "[^"]*"' "$old" 2>/dev/null | sort -u | while IFS= read -r key; do
        grep -q -F -- "$key" "$log" 2>/dev/null && continue
        row=$(grep -F -- "$key" "$old" | tail -1)
        [ -n "$row" ] && printf '%s\n' "$row" >> "$log"
    done
    if ! grep -q -v -F '"account_id"' "$log" 2>/dev/null; then
        row=$(grep -v -F '"account_id"' "$old" 2>/dev/null | tail -1)
        [ -n "$row" ] && printf '%s\n' "$row" >> "$log"
    fi
    return 0
}

if [ "${1:-}" = "--seed" ]; then
    [ $# -eq 3 ] || { echo "usage: rotate-usage-log.sh --seed <old> <log>" >&2; exit 2; }
    seed_latest_rows "$2" "$3"
    exit 0
fi

DIR="${1:-}"
[ -n "$DIR" ] && [ -d "$DIR" ] || exit 0
LOG="$DIR/rate-limits.jsonl"
MARK="$DIR/.rate-limits.month"
LOCK="$DIR/.rotate.lock"
MONTH="${ROTATE_NOW_MONTH:-$(date +%Y-%m)}"

[ "$(cat "$MARK" 2>/dev/null)" = "$MONTH" ] && exit 0
# One refresh rotates; every open session runs the statusline at the same time.
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
[ "$(cat "$MARK" 2>/dev/null)" = "$MONTH" ] && exit 0

if [ -s "$LOG" ]; then
    OLD="$DIR/rate-limits-${ROTATE_STAMP:-$(date +%Y%m%d-%H%M%S)}.jsonl"
    mv "$LOG" "$OLD" || exit 0
    printf '%s\n' "$MONTH" > "$MARK"
    : >> "$LOG"
    seed_latest_rows "$OLD" "$LOG"
    gzip -f "$OLD" 2>/dev/null || true
else
    printf '%s\n' "$MONTH" > "$MARK"
fi
exit 0
