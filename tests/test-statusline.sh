#!/bin/bash
# Test for statusline.sh, on a made-up HOME: where the usage log, the monthly rotation and the
# tmux map are written with and without AGENT_PLATFORM_ROOT, and that nothing outside the root
# (or, with no root, outside the default state folder) is touched.
#
#   bash tests/test-statusline.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/statusline.sh"
T="$(mktemp -d)"
trap 'rm -rf "${T}"' EXIT
pass=0
fail=0

check() { # <what went wrong> <0 when green>
    if [ "$2" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; fi
}

mkdir -p "${T}/home" "${T}/cwd" "${T}/bin"
# tmux stand-in: prints $FAKE_TMUX_SESSION, fails (= not inside tmux) when it is unset.
cat > "${T}/bin/tmux" <<'EOF'
#!/bin/bash
[ -n "${FAKE_TMUX_SESSION:-}" ] && echo "${FAKE_TMUX_SESSION}"
EOF
chmod +x "${T}/bin/tmux"

INPUT='{"session_id":"sess-1","model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":35.2,"total_input_tokens":1200,"total_output_tokens":340},"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":4102444800},"seven_day":{"used_percentage":53,"resets_at":4102444800}}}'
NO_LIMITS='{"session_id":"sess-1","model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":10}}'
MONTH="$(date +%Y-%m)"

# One refresh of the statusline with a bare environment: <input> <NAME=value>...
refresh() {
    local input="$1"
    shift
    (cd "${T}/cwd" && env -i PATH="${T}/bin:${PATH}" HOME="${T}/home" "$@" bash "${SCRIPT}" <<< "${input}")
}
# Everything under the sandbox except <folder to leave out>, with contents: what a run may not change.
outside() {
    (cd "${T}" && find . -path "./$1" -prune -o -print | sort && find . -path "./$1" -prune -o -type f -exec cksum {} + | sort)
}
# The background rotation has no one to wait for it: poll for its mark.
# The rotation writes the mark first (so no other refresh starts a second one) and then carries lines
# over and compresses the old log; it is done when the mark names this month and its lock is gone.
wait_for_rotation() { # <state folder>
    for _ in $(seq 1 50); do
        [ "$(cat "$1/.rate-limits.month" 2>/dev/null)" = "${MONTH}" ] && [ ! -e "$1/.rotate.lock" ] && return 0
        sleep 0.1
    done
    return 1
}
fresh() { rm -rf "${T}/root" "${T}/xdg" "${T}/home/.local" "${T}/home/.claude-work"; }

# 1. With a root: the line goes to <root>/state/statusline, in the form rotate-usage-log.sh matches on
fresh
STATE="${T}/root/state/statusline"
mkdir -p "${STATE}"
echo "${MONTH}" > "${STATE}/.rate-limits.month"
before="$(outside root)"
shown="$(refresh "${INPUT}" "AGENT_PLATFORM_ROOT=${T}/root" FAKE_TMUX_SESSION=tab-a)"
check "the display lost the model or the 5h usage" "$(case "${shown}" in *"Opus 4.6"*"5h:"*) echo 0 ;; *) echo 1 ;; esac)"
check "no line in <root>/state/statusline/rate-limits.jsonl" "$([ "$(wc -l < "${STATE}/rate-limits.jsonl" 2>/dev/null | tr -d ' ')" = "1" ]; echo $?)"
check "the line does not hold the expected values" "$(jq -e '.account_id == "personal" and .session_id == "sess-1" and .model == "Opus 4.6" and .five_hour_pct == 23.5 and .five_hour_resets_at == 4102444800 and .seven_day_pct == 53 and .input_tokens == 1200 and .output_tokens == 340 and .context_pct == 35 and (.timestamp | type) == "number" and (.datetime | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$"))' "${STATE}/rate-limits.jsonl" >/dev/null 2>&1; echo $?)"
check "the line is not in the form \"key\": value that the rotation matches" "$(grep -q '"account_id": "personal", "model": "Opus 4.6"' "${STATE}/rate-limits.jsonl"; echo $?)"
check "the tmux map was not written under the root" "$([ "$(cat "${STATE}/tmux-session-map/tab-a" 2>/dev/null)" = "sess-1" ]; echo $?)"
check "something outside the root was written" "$([ "$(outside root)" = "${before}" ]; echo $?)"
check "a second refresh did not append" "$(refresh "${INPUT}" "AGENT_PLATFORM_ROOT=${T}/root" >/dev/null; [ "$(wc -l < "${STATE}/rate-limits.jsonl" | tr -d ' ')" = "2" ]; echo $?)"

# 2. The account comes from CLAUDE_CONFIG_DIR
refresh "${INPUT}" "AGENT_PLATFORM_ROOT=${T}/root" "CLAUDE_CONFIG_DIR=${T}/home/.claude-work" >/dev/null
check "~/.claude-work did not become the account work" "$([ "$(tail -1 "${STATE}/rate-limits.jsonl" | jq -r .account_id)" = "work" ]; echo $?)"
refresh "${INPUT}" "AGENT_PLATFORM_ROOT=${T}/root" "CLAUDE_CONFIG_DIR=${T}/home/.claude" >/dev/null
check "~/.claude did not become the account personal" "$([ "$(tail -1 "${STATE}/rate-limits.jsonl" | jq -r .account_id)" = "personal" ]; echo $?)"

# 3. A root with a trailing slash names the same place
fresh
mkdir -p "${T}/root/state/statusline"
echo "${MONTH}" > "${T}/root/state/statusline/.rate-limits.month"
refresh "${INPUT}" "AGENT_PLATFORM_ROOT=${T}/root/" >/dev/null
check "a trailing slash on the root moved the log" "$([ -s "${T}/root/state/statusline/rate-limits.jsonl" ]; echo $?)"

# 4. No root: the XDG state folder, under HOME by default; nothing else appears
fresh
DEFAULT="${T}/home/.local/state/claude-code-statusline"
refresh "${INPUT}" FAKE_TMUX_SESSION=tab-b >/dev/null
check "no line in the default state folder" "$([ -s "${DEFAULT}/rate-limits.jsonl" ]; echo $?)"
check "the tmux map is not in the default state folder" "$([ "$(cat "${DEFAULT}/tmux-session-map/tab-b" 2>/dev/null)" = "sess-1" ]; echo $?)"
check "a root folder was made although no root was given" "$([ ! -e "${T}/root" ]; echo $?)"
check "the default wrote outside .local/state/claude-code-statusline" "$([ "$(cd "${T}" && find . -type f ! -path './bin/*' ! -path './home/.local/state/claude-code-statusline/*' | wc -l | tr -d ' ')" = "0" ]; echo $?)"

# 5. XDG_STATE_HOME moves the default; an empty root counts as no root
fresh
refresh "${INPUT}" "XDG_STATE_HOME=${T}/xdg" >/dev/null
check "XDG_STATE_HOME was not honoured" "$([ -s "${T}/xdg/claude-code-statusline/rate-limits.jsonl" ]; echo $?)"
refresh "${INPUT}" AGENT_PLATFORM_ROOT= >/dev/null
check "an empty root was used as a root" "$([ -s "${DEFAULT}/rate-limits.jsonl" ] && [ ! -e "/state" ]; echo $?)"

# 6. Not inside tmux: no map; no rate limits: the display works and no line is recorded
fresh
mkdir -p "${T}/root/state/statusline"
echo "${MONTH}" > "${T}/root/state/statusline/.rate-limits.month"
shown="$(refresh "${NO_LIMITS}" "AGENT_PLATFORM_ROOT=${T}/root")"
check "the display failed without rate limits" "$(case "${shown}" in *"Opus 4.6"*"ctx:"*) echo 0 ;; *) echo 1 ;; esac)"
check "a line was recorded without rate limits" "$([ ! -s "${T}/root/state/statusline/rate-limits.jsonl" ]; echo $?)"
check "a tmux map was written outside tmux" "$([ ! -e "${T}/root/state/statusline/tmux-session-map" ]; echo $?)"

# 7. A new month: the old log is archived and each account's latest line is carried over, inside the root only
fresh
STATE="${T}/root/state/statusline"
mkdir -p "${STATE}"
echo "2000-01" > "${STATE}/.rate-limits.month"
printf '%s\n' '{"timestamp": 1, "account_id": "work", "five_hour_pct": 5}' > "${STATE}/rate-limits.jsonl"
before="$(outside root)"
refresh "${INPUT}" "AGENT_PLATFORM_ROOT=${T}/root" >/dev/null
check "the rotation did not finish the new month" "$(wait_for_rotation "${STATE}"; echo $?)"
check "the old log was not archived" "$(ls "${STATE}"/rate-limits-*.jsonl.gz >/dev/null 2>&1; echo $?)"
check "the resting account (work) was not carried over" "$(grep -q '"account_id": "work", "five_hour_pct": 5' "${STATE}/rate-limits.jsonl"; echo $?)"
check "the rotation wrote outside the root" "$([ "$(outside root)" = "${before}" ]; echo $?)"

# 8. A root that cannot be made: the display still works and the exit is 0
fresh
echo "not a folder" > "${T}/root"
shown="$(refresh "${INPUT}" "AGENT_PLATFORM_ROOT=${T}/root")"
code=$?
rm -f "${T}/root"
check "the display failed when the state folder could not be made" "$(case "${shown}" in *"Opus 4.6"*) echo 0 ;; *) echo 1 ;; esac)"
check "the exit code was not 0 when the state folder could not be made" "${code}"

echo "statusline: ${pass} ok, ${fail} FAIL"
[ "${fail}" -eq 0 ]
