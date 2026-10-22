#!/bin/bash
# Test for rotate-usage-log.sh, on a made-up state folder: nothing happens within the same month; a new
# month moves the log away (every line stays in the archive) and carries only the latest line of each
# resting account into the new log; an account that already has a line gets no older line; and a
# rotation that another session is in the middle of is left alone.
#
#   bash tests/test-rotate-usage-log.sh
set -uo pipefail

ROTATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/src/rotate-usage-log.sh"
T="$(mktemp -d)"
trap 'rm -rf "${T}"' EXIT
pass=0
fail=0

check() { # <what went wrong> <0 when green>
    if [ "$2" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; fi
}
row() { # <account or empty> <marker>
    if [ -n "$1" ]; then printf '{"timestamp": %s, "account_id": "%s", "five_hour_pct": %s}\n' "$2" "$1" "$2"
    else printf '{"timestamp": %s, "five_hour_pct": %s}\n' "$2" "$2"; fi
}
fresh() { rm -rf "${T}/d"; mkdir -p "${T}/d"; D="${T}/d"; LOG="${D}/rate-limits.jsonl"; }

# 1. A folder with no log yet: only the mark is written, no archive is made
fresh
ROTATE_NOW_MONTH=2026-02 bash "${ROTATE}" "${D}"
check "the mark was not written when there is no log" "$([ "$(cat "${D}/.rate-limits.month" 2>/dev/null)" = "2026-02" ]; echo $?)"
check "an archive was made although there is no log" "$(ls "${D}"/rate-limits-*.gz >/dev/null 2>&1; [ $? -ne 0 ]; echo $?)"

# 2. The same month: nothing happens
fresh
{ row personal 1; row work 2; } > "${LOG}"
echo 2026-02 > "${D}/.rate-limits.month"
before="$(cat "${LOG}")"
ROTATE_NOW_MONTH=2026-02 bash "${ROTATE}" "${D}"
check "the log changed within the same month" "$([ "$(cat "${LOG}")" = "${before}" ]; echo $?)"
check "an archive was made within the same month" "$(ls "${D}"/rate-limits-*.gz >/dev/null 2>&1; [ $? -ne 0 ]; echo $?)"

# 3. A new month: every line is archived, the latest line per account (lines without the field count as one) is carried over
fresh
{ row "" 1; row personal 2; row work 3; row personal 4; row "" 5; row work 6; row personal 7; } > "${LOG}"
echo 2026-01 > "${D}/.rate-limits.month"
ROTATE_NOW_MONTH=2026-02 ROTATE_STAMP=stamp bash "${ROTATE}" "${D}"
check "the mark does not name the new month" "$([ "$(cat "${D}/.rate-limits.month")" = "2026-02" ]; echo $?)"
check "the archive does not hold all 7 lines" "$([ "$(gzip -dc "${D}/rate-limits-stamp.jsonl.gz" 2>/dev/null | wc -l | tr -d ' ')" = "7" ]; echo $?)"
check "the file before compression is still there" "$([ ! -e "${D}/rate-limits-stamp.jsonl" ]; echo $?)"
check "the new log is not 3 lines (2 accounts + the line without the field)" "$([ "$(wc -l < "${LOG}" | tr -d ' ')" = "3" ]; echo $?)"
check "the latest personal line (7) was not carried over" "$(grep -q '"account_id": "personal", "five_hour_pct": 7' "${LOG}"; echo $?)"
check "the latest work line (6) was not carried over" "$(grep -q '"account_id": "work", "five_hour_pct": 6' "${LOG}"; echo $?)"
check "the latest line without the field (5) was not carried over" "$(grep -q '{"timestamp": 5, "five_hour_pct": 5}' "${LOG}"; echo $?)"
check "an older personal line (2 or 4) was carried over" "$(grep -q -E '"personal", "five_hour_pct": (2|4)' "${LOG}"; [ $? -ne 0 ]; echo $?)"

# 4. Seeding: an account that already has a line gets no old line (it would look like the latest)
fresh
{ row personal 1; row work 2; row personal 3; } > "${D}/old.jsonl"
row personal 9 > "${LOG}"
bash "${ROTATE}" --seed "${D}/old.jsonl" "${LOG}"
check "an old line was added to the account that is writing (personal)" "$([ "$(grep -c '"personal"' "${LOG}")" = "1" ]; echo $?)"
check "the latest line of the resting account (work) was not added" "$(grep -q '"account_id": "work", "five_hour_pct": 2' "${LOG}"; echo $?)"
check "the new line (9) is not the last personal line" "$(grep '"personal"' "${LOG}" | tail -1 | grep -q '"five_hour_pct": 9'; echo $?)"

# 5. Another session is rotating (its lock folder exists): hands off
fresh
{ row personal 1; } > "${LOG}"
echo 2026-01 > "${D}/.rate-limits.month"
mkdir "${D}/.rotate.lock"
ROTATE_NOW_MONTH=2026-02 bash "${ROTATE}" "${D}"
check "the log was archived although the lock exists" "$([ -s "${LOG}" ] && ! ls "${D}"/rate-limits-*.gz >/dev/null 2>&1; echo $?)"
check "another session's lock was removed" "$([ -d "${D}/.rotate.lock" ]; echo $?)"

# 6. No lock is left behind; a second call in the same month does nothing
fresh
{ row personal 1; } > "${LOG}"
ROTATE_NOW_MONTH=2026-02 ROTATE_STAMP=a bash "${ROTATE}" "${D}"
check "the lock was left behind" "$([ ! -e "${D}/.rotate.lock" ]; echo $?)"
ROTATE_NOW_MONTH=2026-02 ROTATE_STAMP=b bash "${ROTATE}" "${D}"
check "rotated twice in the same month" "$([ ! -e "${D}/rate-limits-b.jsonl.gz" ]; echo $?)"

echo "rotate-usage-log: ${pass} ok, ${fail} FAIL"
[ "${fail}" -eq 0 ]
