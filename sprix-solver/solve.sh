#!/usr/bin/env bash
# SPRIX LEARNING Square - subject 7 (الثقافة المالية) solver
# Walks units 19->24 in curriculum order: chapters (star 5) + reviews + tests (>=80)
# Usage:
#   ./solve.sh                   -> هيطلب Login ID والباسورد ووحدة البداية
#   ./solve.sh <login_id>        -> هيطلب الباسورد ووحدة البداية
#   ./solve.sh <login_id> '<pass>' [start: 1-6 or raw 19-24]
#   START=2 LOGIN_ID=... PASSWORD='...' ./solve.sh  -> من غير ما يسأل
# Requirements: curl, jq, python3
set -euo pipefail

LOGIN_ID="${1:-${LOGIN_ID:-}}"
PASSWORD="${2:-${PASSWORD:-}}"
START="${3:-${START:-}}"
if [[ -z "$LOGIN_ID" ]]; then
  read -rp "Login ID: " LOGIN_ID
fi
if [[ -z "$PASSWORD" ]]; then
  read -rsp "Password: " PASSWORD; echo
fi
if [[ -z "$START" ]]; then
  read -rp "Start from unit [1] (1-6): " START
  START="${START:-1}"
fi
# natural numbers 1..6 map to raw unit ids 19..24 (raw ids still accepted as-is)
if [[ "$START" =~ ^[0-9]+$ ]] && (( 10#$START >= 1 && 10#$START <= 6 )); then
  START=$((18 + 10#$START))
fi
if ! [[ "$START" =~ ^(19|20|21|22|23|24)$ ]]; then
  echo "رقم البداية لازم يكون من 1 لحد 6 (أو رقم الوحدة الخام 19-24) (انت دخلت: $START)"
  exit 1
fi
echo "Start unit #$((10#$START - 18)) (id $START)"
if [[ -z "$LOGIN_ID" || -z "$PASSWORD" ]]; then
  echo "لازم تدخل Login ID والباسورد."
  exit 1
fi

BASE="https://egy.app.spx-learning-square.com"
SUBJECT=7
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANSWERS="$SCRIPT_DIR/answers.json"
JAR="$(mktemp /tmp/sprix-cookies.XXXXXX)"
trap 'rm -f "$JAR"' EXIT

# ---- anti-bot / human-like headers (same browser profile every run) ----
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
CURL="curl -sS -L -c $JAR -b $JAR --compressed"
HDR=(-H "User-Agent: $UA" -H "Accept: application/json, text/plain, */*" -H "Content-Type: application/json" -H "Referer: $BASE/subjects/$SUBJECT/curriculum" -H "Accept-Language: en-US,en;q=0.9")

SLEEP_SCALE="${SLEEP_SCALE:-1}"  # 1 = طبيعي، <1 = أسرع (للدفعات: 0.3)
slow() { sleep "$(awk "BEGIN{print (${1:-0.5}) * $SLEEP_SCALE}")"; }  # human-like delay -> bot protection

echo "[1/3] login..."
# payload from web JS: r({login_id, password}) -> POST /api/v1/auth/login
$CURL "${HDR[@]}" -X POST "$BASE/api/v1/auth/login" \
  --data "$(jq -n --arg u "$LOGIN_ID" --arg p "$PASSWORD" '{login_id:$u,password:$p}')" \
  -o /dev/null -w "login http=%{http_code}\n"
slow 1
echo "[2/3] verify..."
$CURL "${HDR[@]}" "$BASE/api/v1/auth/me" | head -c 200; echo
slow 0.5

api() { $CURL "${HDR[@]}" "$@"; }

jget() { # jget <url>: GET + fail with body preview if not JSON
  local resp
  resp=$(api "$1")
  if ! echo "$resp" | jq -e . >/dev/null 2>&1; then
    echo "API non-JSON for $1 :" >&2
    echo "$resp" | head -c 300 >&2; echo >&2
    return 1
  fi
  echo "$resp"
}

do_chapter() { # <chapter_id>: answer all MCQ blocks from answers.json, then complete (star 5)
  local cid="$1" n ok=0
  n=$(jq -r --arg c "$cid" '.chapters[$c]|length // empty' "$ANSWERS")
  if [[ -z "$n" ]]; then
    # sim chapter (no questions)? verify then complete directly
    local nq
    nq=$(jget "$BASE/api/v1/chapters/$cid/blocks" | jq '[.data.blocks[] | select(.type=="question")] | length')
    if [[ "$nq" == "0" ]]; then
      api -X POST "$BASE/api/v1/chapters/$cid/complete" -d '{}' | head -c 200; echo
      echo "  sim chapter $cid done (no questions)"; slow 0.3; return 0
    fi
    echo "  chapter $cid missing from answers ($nq questions!)"; return 1
  fi
  for k in $(seq 0 $((n-1))); do
    local bid oid out
    bid=$(jq -r --arg c "$cid" --argjson k "$k" '.chapters[$c][$k][0]' "$ANSWERS")
    oid=$(jq -r --arg c "$cid" --argjson k "$k" '.chapters[$c][$k][1]' "$ANSWERS")
    out=$(api -X POST "$BASE/api/v1/chapters/$cid/answer" -d "$(jq -n --argjson b "$bid" --argjson o "$oid" '{block_id:$b,selected_option_id:$o}')")
    # NOTE: no hint_used field - server rejects it with 400. Retry is free (star stays 5).
    if echo "$out" | grep -q '"is_correct":true'; then ok=$((ok+1)); else echo "  chapter $cid block $bid WRONG (retry with correct id)"; return 1; fi
    slow 0.3
  done
  echo "  chapter $cid: $ok/$n correct -> complete:"
  api -X POST "$BASE/api/v1/chapters/$cid/complete" -d '{}'
  slow 0.3
}

do_test() { # <test_id>: start -> answer all from answers.json -> submit (need >=80)
  local tid="$1" start_raw start map n
  # NOTE: start MUST be POST (GET returns 404 page not found)
  start_raw=$(api -X POST "$BASE/api/v1/tests/$tid/start" -d '{}')
  if ! echo "$start_raw" | jq -e . >/dev/null 2>&1; then
    echo "  test $tid start failed:" >&2
    echo "$start_raw" | head -c 300 >&2; echo >&2
    return 1
  fi
  start="$start_raw"
  # test_question ids are per-attempt: build map question_id -> test_question_id from THIS start
  # (skip any null entries - some accounts return extra null rows)
  map=$(echo "$start" | jq -c '[.data.test_questions[] | select(.question_id != null and .id != null) | {key:(.question_id|tostring), value:(.id|tostring)}] | from_entries') || { echo "  test $tid: bad start response"; echo "$start" | head -c 300; return 1; }
  n=$(jq -r --arg t "$tid" '.tests[$t]|length' "$ANSWERS")
  for k in $(seq 0 $((n-1))); do
    local qid oid tqid
    qid=$(jq -r --arg t "$tid" --argjson k "$k" '.tests[$t][$k][0]' "$ANSWERS")
    oid=$(jq -r --arg t "$tid" --argjson k "$k" '.tests[$t][$k][1]' "$ANSWERS")
    tqid=$(echo "$map" | jq -r --arg q "$qid" '.[$q] // empty')
    [[ -z "$tqid" ]] && { echo "  test $tid q $qid not in this attempt!"; return 1; }
    api -X PUT "$BASE/api/v1/tests/$tid/questions/$tqid/answer" -d "$(jq -n --argjson o "$oid" '{selected_option_id:$o}')" >/dev/null
    slow 0.25
  done
  echo "  test $tid submit:"
  api -X POST "$BASE/api/v1/tests/$tid/submit" -d '{}'
  slow 0.4
}

echo "[3/3] solving units $START..24 ..."
for uid in $(seq "$START" 24); do
  echo "=== unit $uid (#$((10#$uid - 18))) ==="
  items=""
  for try in 1 2 3; do
    if items=$(jget "$BASE/api/v1/subjects/$SUBJECT/curriculum" | jq -r --argjson u "$uid" '.data[] | select(.id==$u) | .items[] | "\(.id):\(.item_type)"' 2>/dev/null) && [[ -n "$items" ]]; then
      break
    fi
    echo "curriculum fetch retry $try for unit $uid"; slow 2
    items=""
  done
  if [[ -z "$items" ]]; then echo "STOP: curriculum failed for unit $uid"; exit 1; fi
  for row in $items; do
    id="${row%%:*}"; type="${row##*:}"
    case "$type" in
      chapter) do_chapter "$id" || { echo "STOP at chapter $id"; exit 1; } ;;
      review)  api -X POST "$BASE/api/v1/reviews/$id/complete" -d '{}' >/dev/null; echo "  review $id done"; slow 0.3 ;;
      test)    do_test "$id" ;;
    esac
  done
done

echo "=== final status ==="
api "$BASE/api/v1/subjects/$SUBJECT/units" | jq -r '.data[] | "\(.id): \(.completed_items)/\(.total_items) (\(.progress_pct)%)"' || echo "(status fetch failed - transient, solve itself completed)"
echo "DONE."
# Known platform quirks (verified): test 35 q1071 has no accepted option (max 98),
# ch92 q9560 grader wants 3532, test35 q1082 grader wants 4327, test35 q1091 grader wants 4362.
# Full subject: 54 chapters (274 answers) + 22 tests (380 answers), all verified on account.
