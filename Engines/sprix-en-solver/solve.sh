#!/usr/bin/env bash
# SPRIX LEARNING Square EN - subject 3 (Financial Literacy) solver - self-discovering (no answers.json)
# Walks units 1->6 in curriculum order: chapters (star 5 via option brute-force) + reviews + tests (100% via submit treasure)
# Usage:
#   ./solve.sh                   -> هيطلب Login ID والباسورد ووحدة البداية
#   ./solve.sh <login_id>        -> هيطلب الباسورد ووحدة البداية
#   ./solve.sh <login_id> '<pass>' [start: 1-6]
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
if [[ "$START" =~ ^[0-9]+$ ]] && (( 10#$START >= 1 && 10#$START <= 6 )); then
  START=$((10#$START))
fi
if ! [[ "$START" =~ ^[1-6]$ ]]; then
  echo "رقم البداية لازم يكون من 1 لحد 6 (انت دخلت: $START)"
  exit 1
fi
echo "Start unit #$START"
if [[ -z "$LOGIN_ID" || -z "$PASSWORD" ]]; then
  echo "لازم تدخل Login ID والباسورد."
  exit 1
fi

BASE="https://egy.app.spx-learning-square.com"
SUBJECT=3
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANSWERS="$SCRIPT_DIR/answers.json"
JAR="$(mktemp /tmp/sprixen-cookies.XXXXXX)"
trap 'rm -f "$JAR"' EXIT

# ---- anti-bot / human-like headers (same browser profile every run) ----
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
CURL="curl -sS -L -c $JAR -b $JAR --compressed"
HDR=(-H "User-Agent: $UA" -H "Accept: application/json, text/plain, */*" -H "Content-Type: application/json" -H "Referer: $BASE/subjects/$SUBJECT/curriculum" -H "Accept-Language: en-US,en;q=0.9")

SLEEP_SCALE="${SLEEP_SCALE:-0.05}"  # 0.05 = فائقة السرعة
slow() { sleep "$(awk "BEGIN{print (${1:-0.1}) * $SLEEP_SCALE}")"; }  # microscopic jitter delay

echo "[1/3] login..."
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

# ───────── static answers.json helpers ─────────
# Shape: { "chapters": { "<cid>": [[block_id, option_id], ...] },
#          "tests":    { "<tid>": [[question_id, option_id], ...] } }
[[ -s "$ANSWERS" ]] || echo '{}' > "$ANSWERS"
jq -e 'has("chapters")' "$ANSWERS" >/dev/null 2>&1 || { jq '.chapters={}' "$ANSWERS" > "$ANSWERS.tmp" && mv "$ANSWERS.tmp" "$ANSWERS"; }
jq -e 'has("tests")' "$ANSWERS" >/dev/null 2>&1 || { jq '.tests={}' "$ANSWERS" > "$ANSWERS.tmp" && mv "$ANSWERS.tmp" "$ANSWERS"; }

persist_pairs() { # <kind: chapters|tests> <id> <pairs-json-array>
  local kind="$1" id="$2" arr="$3" tmp
  tmp="$(mktemp)"
  jq --argjson a "$arr" --arg id "$id" --arg k "$kind" '.[$k][$id] = $a' "$ANSWERS" > "$tmp" && mv "$tmp" "$ANSWERS"
}

do_chapter() { # <chapter_id>: use static answers, else brute-force each MCQ option until is_correct; then complete (star 5)
  local cid="$1"
  local blocks nq
  blocks=$(jget "$BASE/api/v1/chapters/$cid/blocks") || return 1
  nq=$(echo "$blocks" | jq '[.data.blocks[] | select(.type=="question")] | length')
  if [[ "$nq" == "0" ]]; then
    api -X POST "$BASE/api/v1/chapters/$cid/complete" -d '{}' | head -c 200; echo
    echo "  sim chapter $cid done (no questions)"; slow 0.3; return 0
  fi

  local static pairsfile arr
  static=$(jq -c --arg c "$cid" '.chapters[$c] // empty' "$ANSWERS" 2>/dev/null)
  if [[ "${HARVEST:-0}" != "1" && -n "$static" && "$static" != "null" ]]; then
    echo "  ch$cid: using $(echo "$static" | jq 'length') static answers (skip brute-force)"
    echo "$static" | jq -c '.[]' | while read -r pair; do
      local bid oid out
      bid=$(echo "$pair" | jq -r '.[0]')
      oid=$(echo "$pair" | jq -r '.[1]')
      out=$(api -X POST "$BASE/api/v1/chapters/$cid/answer" -d "$(jq -n --argjson b "$bid" --argjson o "$oid" '{block_id:$b,selected_option_id:$o}')")
      if ! echo "$out" | grep -q '"is_correct":true'; then echo "  ch$cid block$bid: static answer rejected"; fi
      slow 0.2
    done
  else
    pairsfile="$(mktemp)"
    echo "$blocks" | jq -c '.data.blocks[] | select(.type=="question") | {block_id: .id, qid: .question_id, options: [.options[] | .id]}' | while read -r row; do
      local bid qid opts found=0 oid out
      bid=$(echo "$row" | jq -r .block_id)
      qid=$(echo "$row" | jq -r .qid)
      opts=$(echo "$row" | jq -c .options)
      for oid in $(echo "$opts" | jq -r '.[]'); do
        out=$(api -X POST "$BASE/api/v1/chapters/$cid/answer" -d "$(jq -n --argjson b "$bid" --argjson o "$oid" '{block_id:$b,selected_option_id:$o}')")
        if echo "$out" | grep -q '"is_correct":true'; then
          echo "  ch$cid q$qid block$bid: option $oid CORRECT"
          echo "$bid $oid" >> "$pairsfile"
          found=1; break
        fi
        slow 0.2
      done
      if [[ "$found" == "0" ]]; then
        echo "  ch$cid q$qid block$bid: NO accepted option (all $(echo "$opts" | jq 'length') tried) - continuing"
      fi
    done
    if [[ -s "$pairsfile" ]]; then
      arr=$(jq -R -s 'split("\n") | map(select(length>0) | split(" ") | map(tonumber))' "$pairsfile")
      persist_pairs chapters "$cid" "$arr"
      echo "  ch$cid: saved $(echo "$arr" | jq 'length') answers to answers.json"
    fi
    rm -f "$pairsfile"
  fi

  echo "  chapter $cid complete:"
  api -X POST "$BASE/api/v1/chapters/$cid/complete" -d '{}' | head -c 200; echo
  slow 0.3
}

do_test() { # <test_id>: learn pass (guess+submit harvest) -> apply pass (correct+submit 100%)
  local tid="$1" start_raw map n
  # NOTE: start MUST be POST (GET returns 404 page not found)
  start_raw=$(api -X POST "$BASE/api/v1/tests/$tid/start" -d '{}')
  if ! echo "$start_raw" | jq -e . >/dev/null 2>&1; then
    echo "  test $tid start failed:" >&2
    echo "$start_raw" | head -c 300 >&2; echo >&2
    return 1
  fi
  local ansfile="/tmp/sprixen_test_${tid}.json"
  local static arr
  static=$(jq -c --arg t "$tid" '.tests[$t] // empty' "$ANSWERS" 2>/dev/null)
  if [[ "${HARVEST:-0}" != "1" && -n "$static" && "$static" != "null" ]]; then
    echo "$static" | jq 'map({key:(.[0]|tostring), value:.[1]}) | from_entries' > "$ansfile"
    echo "  test $tid: using $(jq 'length' "$ansfile") static answers (skip learn pass)"
  else
  # learn pass: answer all with first option, then submit -> treasure reveals is_correct per option
  map=$(echo "$start_raw" | jq -c '[.data.test_questions[] | select(.question_id != null and .id != null) | {key:(.question_id|tostring), value:(.id|tostring)}] | from_entries')
  n=$(echo "$start_raw" | jq '[.data.test_questions[] | select(.question_id != null)] | length')
  local k
  for k in $(seq 0 $((n-1))); do
    local qid tqid oid
    qid=$(echo "$start_raw" | jq -r "[.data.test_questions[] | select(.question_id != null)][ $k ].question_id")
    tqid=$(echo "$map" | jq -r --arg q "$qid" '.[$q]')
    oid=$(echo "$start_raw" | jq -r --arg q "$qid" '.data.options[$q][0].id')
    [[ -z "$tqid" || "$tqid" == "null" || -z "$oid" || "$oid" == "null" ]] && { echo "  test $tid q$qid: bad map/opt"; return 1; }
    api -X PUT "$BASE/api/v1/tests/$tid/questions/$tqid/answer" -d "$(jq -n --argjson o "$oid" '{selected_option_id:$o}')" >/dev/null
    slow 0.2
  done
  echo "  test $tid learn-submit:"
  local sub
  sub=$(api -X POST "$BASE/api/v1/tests/$tid/submit" -d '{}')
  slow 0.3
  # harvest correct option per question from submit treasure: .data.options[qid][].is_correct==true
  local ansfile="/tmp/sprixen_test_${tid}.json"
  echo '{}' > "$ansfile"
  echo "$sub" | jq -c '.data.options | to_entries[] | {qid: .key, real: ([.value[] | select(.is_correct==true) | .id] | first)}' 2>/dev/null | while read -r row; do
    local qid real
    qid=$(echo "$row" | jq -r .qid)
    real=$(echo "$row" | jq -r .real)
    if [[ -n "$real" && "$real" != "null" ]]; then
      jq --arg q "$qid" --argjson o "$real" '.[$q] = $o' "$ansfile" > "$ansfile.tmp" && mv "$ansfile.tmp" "$ansfile"
    fi
  done
  local nh
  nh=$(jq 'length' "$ansfile")
  echo "  test $tid harvested $nh correct answers"
  if [[ "$nh" == "0" ]]; then
    echo "  test $tid: harvest empty - check submit response"
    echo "$sub" | head -c 300; echo
    rm -f "$ansfile"
    return 1
  fi
  arr=$(jq '[to_entries[] | [(.key|tonumber), .value]]' "$ansfile")
  persist_pairs tests "$tid" "$arr"
  echo "  test $tid: saved $(echo "$arr" | jq 'length') answers to answers.json"
  fi
  # apply pass: restart, answer all correctly, submit -> 100%
  start_raw=$(api -X POST "$BASE/api/v1/tests/$tid/start" -d '{}')
  map=$(echo "$start_raw" | jq -c '[.data.test_questions[] | select(.question_id != null and .id != null) | {key:(.question_id|tostring), value:(.id|tostring)}] | from_entries')
  n=$(echo "$start_raw" | jq '[.data.test_questions[] | select(.question_id != null)] | length')
  for k in $(seq 0 $((n-1))); do
    local qid tqid oid
    qid=$(echo "$start_raw" | jq -r "[.data.test_questions[] | select(.question_id != null)][ $k ].question_id")
    tqid=$(echo "$map" | jq -r --arg q "$qid" '.[$q]')
    oid=$(jq -r --arg q "$qid" '.[$q] // empty' "$ansfile")
    if [[ -z "$oid" || "$oid" == "null" ]]; then
      echo "  test $tid q$qid: no harvested answer - skip"
      continue
    fi
    api -X PUT "$BASE/api/v1/tests/$tid/questions/$tqid/answer" -d "$(jq -n --argjson o "$oid" '{selected_option_id:$o}')" >/dev/null
    slow 0.2
  done
  echo "  test $tid apply-submit:"
  api -X POST "$BASE/api/v1/tests/$tid/submit" -d '{}' | jq -c '.data.response | {score: .total_score, passed: .passed}' 2>/dev/null || echo "(submit ok)"
  slow 0.3
  rm -f "$ansfile" "$ansfile.tmp"
}

echo "[3/3] solving units $START..${END_UNIT:-6} ..."
CURRICULUM_DATA=$(jget "$BASE/api/v1/subjects/$SUBJECT/curriculum")
for uid in $(seq "$START" "${END_UNIT:-6}"); do
  echo "=== unit $uid ==="
  items=$(echo "$CURRICULUM_DATA" | jq -r --argjson u "$uid" '.data[] | select(.id==$u) | .items[] | "\(.id):\(.item_type)"' 2>/dev/null)
  if [[ -z "$items" ]]; then
    echo "STOP: curriculum failed for unit $uid"; exit 1
  fi
  for row in $items; do
    id="${row%%:*}"; type="${row##*:}"
    case "$type" in
      chapter) do_chapter "$id" || { echo "STOP at chapter $id"; exit 1; } ;;
      review)  api -X POST "$BASE/api/v1/reviews/$id/complete" -d '{}' >/dev/null; echo "  review $id done"; slow 0.3 ;;
      test)    do_test "$id" || { echo "STOP at test $id"; exit 1; } ;;
    esac
  done
done

echo "=== final status ==="
api "$BASE/api/v1/subjects/$SUBJECT/units" | jq -r '.data[] | "unit \(.id): \(.completed_items)/\(.total_items) (\(.progress_pct|floor)%)"' || echo "(status fetch failed - transient, solve itself completed)"
echo "DONE."
# ---- sprix-en API notes (discovered by solving) ----
# Subject 3 "Financial Literacy" (lang=en), units 1-6, ~137 items (chapters+reviews+tests)
# Account 482438443 also has subject 8 "Global Finance Quest" (separate course, not covered here)
# Chapter MCQ brute-force: wrong answer does NOT reveal correct_option_id (null) -> try each option until is_correct:true (retry free, star stays 5)
# Test treasure: POST submit -> .data.options[qid][].is_correct:true reveals all correct answers -> restart + answer correctly -> 100%
# Test start MUST be POST (GET=404 page not found); test_question ids are per-attempt (rebuild map each start)
# Locked content: 403 chapter_locked / test_locked -> complete previous first (sequential)
# Do NOT send hint_used field (server rejects 400)
# Sim chapters (0 questions): just POST complete
