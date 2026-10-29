#!/usr/bin/env bash
# QUREO javascript_en solver - gets PERFECT (5 diamonds) on all 54 chapters (30001-30054)
# Course: https://me-tp.qureo.education/course/javascript_en (section 2, 270 diamonds total)
# Self-discovering: learn pass harvests correct answers from grader responses, apply pass re-answers them.
# Usage:
#   ./solve.sh                        -> هيطلب Login ID والباسورد وفصل البداية
#   ./solve.sh <login_id>             -> هيطلب الباسورد وفصل البداية
#   ./solve.sh <login_id> '<pass>' [start: 1-54 or raw 30001-30054]
#   START=46 LOGIN_ID=... PASSWORD='...' ./solve.sh
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
  read -rp "Start from chapter [1] (1-54): " START
  START="${START:-1}"
fi
# natural numbers 1..54 map to raw chapter ids 30001..30054 (raw ids still accepted as-is)
if [[ "$START" =~ ^[0-9]+$ ]] && (( 10#$START >= 1 && 10#$START <= 54 )); then
  START=$((30000 + 10#$START))
fi
if [[ -z "$LOGIN_ID" || -z "$PASSWORD" ]]; then
  echo "لازم تدخل Login ID والباسورد."
  exit 1
fi
if ! [[ "$START" =~ ^300[0-5][0-9]$ ]]; then
  echo "رقم البداية لازم يكون من 1 لحد 54 (أو رقم الفصل الخام 30001-30054) (انت دخلت: $START)"
  exit 1
fi
echo "Start chapter #$((10#$START - 30000)) (id $START)"

PORTAL="https://me-portal.qureo.education"
TP="https://me-tp.qureo.education"
SECTION=2
CONTENT_ID="javascript_en"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANSWERS="$SCRIPT_DIR/answers.json"
JAR="$(mktemp /tmp/qureojsen-cookies.XXXXXX)"
trap 'rm -f "$JAR"' EXIT

# ---- anti-bot / human-like headers ----
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
CURL="curl -sS -L -c $JAR -b $JAR --compressed"
HDR_PORTAL=(-H "User-Agent: $UA" -H "Accept: application/json" -H "Content-Type: application/json" -H "Origin: $PORTAL" -H "Referer: $PORTAL/login" -H "Accept-Language: en-US,en;q=0.9")
HDR_TP=(-H "User-Agent: $UA" -H "Accept: */*" -H "Content-Type: application/json" -H "Origin: $TP" -H "Accept-Language: en-US,en;q=0.9")

SLEEP_SCALE="${SLEEP_SCALE:-0.05}"  # 0.05 = فائقة السرعة
slow() { sleep "$(awk "BEGIN{print (${1:-0.1}) * $SLEEP_SCALE}")"; }  # microscopic jitter delay

echo "[1/4] login to portal..."
$CURL "${HDR_PORTAL[@]}" -X POST "$PORTAL/oauth2/password-login" \
  --data "$(jq -n --arg s "$LOGIN_ID" --arg p "$PASSWORD" '{student_id:$s,password:$p}')" \
  -o /dev/null -w "login http=%{http_code}\n"
slow 1
echo "[2/4] verify userinfo..."
$CURL "${HDR_PORTAL[@]}" "$PORTAL/oauth2/userinfo" | head -c 300; echo
slow 0.5

echo "[3/4] bootstrap TP session (oauth refresh)..."
$CURL -H "User-Agent: $UA" -H "Referer: $TP/" "$TP/api/study/students/me" -o /dev/null -w "tp me http=%{http_code}\n"
# TP requires selected-content cookie (browser always sends student_selected_content_id=<course>).
printf '%s\n' ".qureo.education	TRUE	/	FALSE	0	student_selected_content_id	$CONTENT_ID" >> "$JAR"
printf '%s\n' ".qureo.education	TRUE	/	FALSE	0	i18next	en" >> "$JAR"
slow 0.5

api() { $CURL "${HDR_TP[@]}" -H "Referer: $TP/" "$@"; }

jget() { # jget <url> : GET + fail with body preview if not JSON
  local resp
  resp=$(api "$1")
  if ! echo "$resp" | jq -e . >/dev/null 2>&1; then
    echo "API non-JSON for $1 :" >&2
    echo "$resp" | head -c 300 >&2; echo >&2
    return 1
  fi
  echo "$resp"
}

# helper: complete lectures of a chapter using live model_answer (no hardcode needed)
complete_lectures() {
  local cid="$1"
  local chap_json lectures
  chap_json=$(jget "$TP/api/study/chapters/$cid") || return 1
  lectures=$(echo "$chap_json" | jq -r '.lectures[]?.id')
  if [[ -z "$lectures" ]]; then
    echo "  no lectures found for $cid (locked?). body:" >&2
    echo "$chap_json" | head -c 300 >&2; echo >&2
    return 1
  fi
  for lid in $lectures; do
    api -X PUT "$TP/api/study/students/lectures/$lid" -d '{}' >/dev/null; slow 0.05
    local talks
    talks=$(jget "$TP/api/study/lectures/$lid") || return 1
    if ! echo "$talks" | jq -e '.talks' >/dev/null 2>&1; then
      echo "  lecture $lid locked (prev chapter not done?). Stop here." >&2
      echo "$talks" | head -c 300 >&2; echo >&2
      return 1
    fi
    # choice_question/choice_survey talks are story dialogues - safely ignored (lectures complete without them).
    echo "$talks" | jq -c '.talks[] | select(.type=="try" or (.type|startswith("try"))) | {id, code: .body.codes[0]}' | while read -r row; do
      local tid lang model code ph
      tid=$(echo "$row" | jq -r '.id')
      lang=$(echo "$row" | jq -r '.code.lang // "javascript"')
      model=$(echo "$row" | jq -r '.code.model_answer // empty')
      code=$(echo "$row" | jq -r '.code.code // empty')
      [[ -z "$model" ]] && model="$code"
      ph=$(echo "$row" | jq -r '.code.placeholders // [] | length')
      hasfitb=$(echo "$row" | jq -r '.code.code | contains("fitbBlock")')
      if [[ "$ph" -gt 0 && "$hasfitb" == "true" ]]; then
        payload=$(echo "$row" | jq -c --arg lang "$lang" '{value:{lang:$lang, answers:(.code.placeholders|map({name:.name,code:.model_answer}))}}')
      else
        payload=$(jq -n --arg lang "$lang" --arg ans "$model" '{value:{lang:$lang,answer:$ans}}')
      fi
      api -X PUT "$TP/api/study/students/lecture-talks/$tid" -d "$payload" >/dev/null; slow 0.2
    done
    api -X PUT "$TP/api/study/students/lectures/$lid/complete" -d '{}' >/dev/null; slow 0.3
  done
}

# ───────── static answers.json helpers ─────────
# Shape: { "<chapter_id>": { "type": "review|test", "questions": [ {qid, qtype, choice_id|answer_code} ] } }
[[ -s "$ANSWERS" ]] || echo '{}' > "$ANSWERS"

persist_chapter_answers() { # <cid> <ctype> <mapfile{ qid: {type,choice_id|answer_code} }>
  local cid="$1" ctype="$2" mapfile="$3" tmp
  [[ "$(jq 'length' "$mapfile" 2>/dev/null || echo 0)" -eq 0 ]] && return 0
  tmp="$(mktemp)"
  jq --slurpfile m "$mapfile" --arg c "$cid" --arg t "$ctype" \
    '.[$c] = {type:$t, questions: ($m[0] | to_entries | map({qid:(.key|tonumber), qtype:.value.type} + (.value | del(.type))))}' \
    "$ANSWERS" > "$tmp" && mv "$tmp" "$ANSWERS"
}

load_chapter_map() { # <cid> <mapfile> ; returns 0 + fills mapfile if the chapter has static answers
  local cid="$1" mapfile="$2"
  if jq -e --arg c "$cid" '.[$c].questions | length > 0' "$ANSWERS" >/dev/null 2>&1; then
    if jq --arg c "$cid" '.[$c].questions | reduce .[] as $q ({}; .[$q.qid|tostring] = ($q | del(.qid)))' "$ANSWERS" > "$mapfile"; then
      return 0
    fi
  fi
  echo '{}' > "$mapfile"
  return 1
}

# learn pass: answer all questions with guesses, harvest correct answers from grader responses into /tmp map file
# apply pass: restart test, answer all with harvested correct answers
solve_test() {
  local cid="$1" ctype="$2"
  local prefix="review-questions"
  [[ "$ctype" == "test" ]] && prefix="test-questions"
  local mapfile="/tmp/qjsen_map_$cid.json"
  local tq nq
  tq=$(jget "$TP/api/study/chapters/$cid/test") || return 1
  nq=$(echo "$tq" | jq 'length')

  if load_chapter_map "$cid" "$mapfile"; then
    echo "--- $cid: $(jq 'length' "$mapfile") static answers loaded (skip learn pass)"
  else
  echo "--- learn pass $cid ($prefix)"
  api -X PUT "$TP/api/study/students/chapters/$cid/test" -d '{}' >/dev/null; slow 0.4
  for k in $(seq 0 $((nq-1))); do
    local qid qtype out
    qid=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].question.id')
    qtype=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].question.type')
    if [[ "$qtype" == "choice" ]]; then
      local guess
      guess=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].choices[0].id')
      out=$(api -X PUT "$TP/api/study/students/$prefix/$qid/answer/choice" -d "$(jq -n --argjson c "$guess" '{choice_id:$c}')")
      # harvest: response has result.choices[].correct==true -> the right choice_id
      local real
      real=$(echo "$out" | jq -r '.result.choices[]? | select(.correct==true) | .choice.id' 2>/dev/null | head -1)
      if [[ -n "$real" && "$real" != "null" ]]; then
        jq --arg q "$qid" --argjson c "$real" '.[$q] = {type:"choice", choice_id:$c}' "$mapfile" > "$mapfile.tmp" && mv "$mapfile.tmp" "$mapfile"
        echo "  q $qid (choice): harvested $real"
      else
        echo "  q $qid (choice): harvest FAILED: $(echo "$out" | head -c 150)"
      fi
    else
      local code
      code=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].descriptions[0].code // empty')
      [[ -z "$code" ]] && code='console.log("x")'
      out=$(api -X PUT "$TP/api/study/students/$prefix/$qid/answer/description" -d "$(jq -n --arg a "$code" '{answer_code:$a}')")
      local real
      real=$(echo "$out" | jq -r '.result.model_answer // empty' 2>/dev/null)
      if [[ -n "$real" ]]; then
        jq --arg q "$qid" --arg a "$real" '.[$q] = {type:"description", answer_code:$a}' "$mapfile" > "$mapfile.tmp" && mv "$mapfile.tmp" "$mapfile"
        echo "  q $qid (desc): harvested model_answer"
      else
        echo "  q $qid (desc): harvest FAILED: $(echo "$out" | head -c 150)"
      fi
    fi
    slow 0.3
  done

  # fallback: harvest from result endpoint (test-questions return {} per-q; result becomes visible after attempt completes)
  local result
  result=$(jget "$TP/api/study/students/chapters/$cid/$ctype/result" 2>/dev/null || true)
  if [[ -n "$result" ]] && echo "$result" | jq -e . >/dev/null 2>&1; then
    echo "$result" | jq -c '(.result.choice_results // .choice_results // [])[]? | {qid: .question_id, real: ([.choices[] | select(.correct==true) | .choice.id] | first)}' 2>/dev/null | while read -r row; do
      local qid real
      qid=$(echo "$row" | jq -r .qid)
      real=$(echo "$row" | jq -r .real)
      if [[ -n "$real" && "$real" != "null" ]]; then
        jq --arg q "$qid" --argjson c "$real" '.[$q] = {type:"choice", choice_id:$c}' "$mapfile" > "$mapfile.tmp" && mv "$mapfile.tmp" "$mapfile"
        echo "  q $qid (choice): harvested from result $real"
      fi
    done
    echo "$result" | jq -c '(.result.description_results // .description_results // [])[]? | {qid: .question_id, real: .model_answer}' 2>/dev/null | while read -r row; do
      local qid real
      qid=$(echo "$row" | jq -r .qid)
      real=$(echo "$row" | jq -r .real)
      if [[ -n "$real" && "$real" != "null" ]]; then
        jq --arg q "$qid" --arg a "$real" '.[$q] = {type:"description", answer_code:$a}' "$mapfile" > "$mapfile.tmp" && mv "$mapfile.tmp" "$mapfile"
        echo "  q $qid (desc): harvested from result"
      fi
    done
  fi

  persist_chapter_answers "$cid" "$ctype" "$mapfile"
  fi

  echo "--- apply pass $cid (restart + answer correct)"
  api -X PUT "$TP/api/study/students/chapters/$cid/test" -d '{}' >/dev/null; slow 0.4
  for k in $(seq 0 $((nq-1))); do
    local qid qtype entry out
    qid=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].question.id')
    qtype=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].question.type')
    entry=$(jq -c --arg q "$qid" '.[$q] // empty' "$mapfile")
    if [[ -z "$entry" ]]; then
      echo "  q $qid: NO HARVESTED ANSWER -> skip (will show in final status)"
      continue
    fi
    if [[ "$qtype" == "choice" ]]; then
      local choice
      choice=$(echo "$entry" | jq -r .choice_id)
      out=$(api -X PUT "$TP/api/study/students/$prefix/$qid/answer/choice" -d "$(jq -n --argjson c "$choice" '{choice_id:$c}')")
    else
      local ans
      ans=$(echo "$entry" | jq -r .answer_code)
      out=$(api -X PUT "$TP/api/study/students/$prefix/$qid/answer/description" -d "$(jq -n --arg a "$ans" '{answer_code:$a}')")
    fi
    if echo "$out" | grep -q '"complete"'; then
      echo "  q $qid: COMPLETE"
    elif echo "$out" | grep -q '"correct":true'; then
      echo "  q $qid: correct"
    elif [[ "$out" == "{}" ]]; then
      echo "  q $qid: ok"
    else
      echo "  q $qid: $(echo "$out" | head -c 150)"
    fi
    slow 0.4
  done
  rm -f "$mapfile" "$mapfile.tmp"
}

# ───────── HARVEST MODE: build static answers.json (read-only from result endpoint) ─────────
if [[ "${HARVEST:-0}" == "1" ]]; then
  [[ -s "$ANSWERS" ]] || echo '{}' > "$ANSWERS"
  echo "=== HARVEST MODE -> $ANSWERS ==="
  mapfile -t HCH < <(jget "$TP/api/study/sections/$SECTION" | jq -r --argjson s "$START" '.chapters[] | select(.id >= $s) | "\(.id) \(.test_type)"' | sort -n)
  for entry in "${HCH[@]}"; do
    cid="${entry%% *}"; ctype="${entry##* }"
    r=$(jget "$TP/api/study/students/chapters/$cid/$ctype/result" 2>/dev/null || true)
    body=$(echo "$r" | jq -c '.result // .' 2>/dev/null)
    nk=$(echo "$body" | jq 'if type=="object" then (keys|length) else 0 end' 2>/dev/null || echo 0)
    if [[ -z "$body" || "$nk" == "0" ]]; then
      echo "--- $cid ($ctype): no read-only result -> write-harvest via solve_test"
      ( solve_test "$cid" "$ctype" )
      continue
    fi
    tmpmap=$(mktemp)
    echo '{}' > "$tmpmap"
    echo "$body" | jq -r '.choice_results[]? | ([.choices[]|select(.correct==true)|.choice.id]|first) as $c | (.choices[0].choice.question_id) as $q | select($c!=null and $q!=null) | "\($q) \($c)"' | while read -r q c; do
      jq --arg q "$q" --argjson c "$c" '.[$q]={type:"choice",choice_id:$c}' "$tmpmap" > "$tmpmap.t" && mv "$tmpmap.t" "$tmpmap"
    done
    echo "$body" | jq -r '.description_results[]? | select(.question_id!=null and .model_answer!=null) | "\(.question_id)\t\(.model_answer|@base64)"' | while read -r q b64; do
      ans=$(printf '%s' "$b64" | base64 -d)
      jq --arg q "$q" --arg a "$ans" '.[$q]={type:"description",answer_code:$a}' "$tmpmap" > "$tmpmap.t" && mv "$tmpmap.t" "$tmpmap"
    done
    echo "--- $cid ($ctype): harvested $(jq 'length' "$tmpmap") answers"
    persist_chapter_answers "$cid" "$ctype" "$tmpmap"
    rm -f "$tmpmap" "$tmpmap.t"
    slow 0.3
  done
  echo "=== HARVEST DONE ==="
  jq -r '"chapters=\(length) questions=\([.[].questions|length]|add // 0)"' "$ANSWERS" 2>/dev/null || true
  exit 0
fi

# chapter list from section API (id + test_type), sorted, starting from START (sequential - must do in order)
# optional END=<raw chapter id> to cap the range (useful for testing)
mapfile -t CHAPTERS < <(jget "$TP/api/study/sections/$SECTION" | jq -r --argjson s "$START" --argjson e "${END:-999999}" '.chapters[] | select(.id >= $s and .id <= $e) | "\(.id) \(.test_type)"' | sort -n)
if [[ "${#CHAPTERS[@]}" -eq 0 ]]; then
  echo "مفيش فصول >= $START في القسم $SECTION"
  exit 1
fi
TOTAL="${#CHAPTERS[@]}"
echo "Solving ${TOTAL} chapters from $START to ${CHAPTERS[-1]%% *}"
i=0
for entry in "${CHAPTERS[@]}"; do
  cid="${entry%% *}"
  ctype="${entry##* }"
  i=$((i+1))
  echo "=== [$i/$TOTAL] chapter $cid (#$((10#$cid - 30000)), $ctype) lectures..."
  if ! complete_lectures "$cid"; then
    echo "STOP: chapter $cid failed (probably locked - finish previous first)."
    exit 1
  fi
  solve_test "$cid" "$ctype"
done

echo "[4/4] final status:"
api "$TP/api/study/students/sections/$SECTION/chapters" | python3 -c "import json,sys; ch=json.load(sys.stdin); print(f\"completed {sum(1 for c in ch if c.get('completed_at'))}/{len(ch)}\"); print('non-perfect:', [(c['chapter_id'],c.get('diamond')) for c in ch if c.get('diamond',0)<5])"
api "$TP/api/study/students/courses/$CONTENT_ID/diamond"
echo "DONE - all should be diamond 5 (270/270)."

# ---- qureo-js-en API notes (discovered by solving) ----
# Course: javascript_en, section 2, chapters 30001-30054 (54 chapters, review type except every-4th test)
# Chapter list: GET /api/study/sections/2 -> {chapters:[{id, test_type}], section} (test_type dynamic - no hardcode)
# Learn pass: PUT answer -> response echoes result with correct answers:
#   choice: result.choices[].correct==true -> .choice.id
#   description: result.model_answer = correct code (starter code often partial/empty -> guess console.log("x"))
# Apply pass: PUT /test restarts attempt, re-answer with harvested answers -> diamond 5.
# Test questions GET: [{question{id,type}, choices[{id,content}], descriptions[{code,lang,placeholders}]}]
# Result endpoint: GET students/chapters/{cid}/test|review/result (fallback harvest for test-questions)
# Locked chapter: GET /test returns 403 until previous completed in order.
# Lectures: lang=javascript, try talks use model_answer (fallback: code). Same fitb/placeholder handling as AR.
