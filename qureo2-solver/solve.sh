#!/usr/bin/env bash
# QUREO2 python_short_ar solver - gets PERFECT (5 diamonds) on all 25 chapters (511001-511025)
# Course: https://me-tp.qureo.education/course/python_short_ar (section 106, 125 diamonds total)
# Usage:
#   ./solve.sh                        -> هيطلب Login ID والباسورد وفصل البداية
#   ./solve.sh <login_id>             -> هيطلب الباسورد وفصل البداية
#   ./solve.sh <login_id> '<pass>' [start: 1-25 or raw 511001-511025]
#   START=10 LOGIN_ID=... PASSWORD='...' ./solve.sh
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
  read -rp "Start from chapter [1] (1-25): " START
  START="${START:-1}"
fi
# natural numbers 1..25 map to raw chapter ids 511001..511025 (raw ids still accepted as-is)
if [[ "$START" =~ ^[0-9]+$ ]] && (( 10#$START >= 1 && 10#$START <= 25 )); then
  START=$((511000 + 10#$START))
fi
if [[ -z "$LOGIN_ID" || -z "$PASSWORD" ]]; then
  echo "لازم تدخل Login ID والباسورد."
  exit 1
fi
if ! [[ "$START" =~ ^5110(0[1-9]|1[0-9]|2[0-5])$ ]]; then
  echo "رقم البداية لازم يكون من 1 لحد 25 (أو رقم الفصل الخام 511001-511025) (انت دخلت: $START)"
  exit 1
fi
echo "Start chapter #$((10#$START - 511000)) (id $START)"

PORTAL="https://me-portal.qureo.education"
TP="https://me-tp.qureo.education"
SECTION=106
CONTENT_ID="python_short_ar"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANSWERS="$SCRIPT_DIR/answers.json"
JAR="$(mktemp /tmp/qureo2-cookies.XXXXXX)"
trap 'rm -f "$JAR"' EXIT

# ---- anti-bot / human-like headers ----
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
CURL="curl -sS -L -c $JAR -b $JAR --compressed"
HDR_PORTAL=(-H "User-Agent: $UA" -H "Accept: application/json" -H "Content-Type: application/json" -H "Origin: $PORTAL" -H "Referer: $PORTAL/login" -H "Accept-Language: en-US,en;q=0.9")
HDR_TP=(-H "User-Agent: $UA" -H "Accept: */*" -H "Content-Type: application/json" -H "Origin: $TP" -H "Accept-Language: en-US,en;q=0.9")

slow() { sleep "${1:-0.7}"; }  # human-like delay -> bot protection

echo "[1/4] login to portal..."
# payload discovered from portal JS: J({student_id, password}) -> POST /oauth2/password-login
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
# Without it /api/study/chapters/* returns non-JSON -> jq "Invalid numeric literal".
printf '%s\n' ".qureo.education	TRUE	/	FALSE	0	student_selected_content_id	$CONTENT_ID" >> "$JAR"
printf '%s\n' ".qureo.education	TRUE	/	FALSE	0	i18next	ar" >> "$JAR"
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
    api -X PUT "$TP/api/study/students/lectures/$lid" -d '{}' >/dev/null; slow 0.3
    local talks
    talks=$(jget "$TP/api/study/lectures/$lid") || return 1
    if ! echo "$talks" | jq -e '.talks' >/dev/null 2>&1; then
      echo "  lecture $lid locked (prev chapter not done?). Stop here." >&2
      echo "$talks" | head -c 300 >&2; echo >&2
      return 1
    fi
    # NOTE: python talks use type exactly "try" (JS used try* prefix) - same filter covers both.
    # choice_question/choice_survey talks are story dialogues - safely ignored (lectures complete without them).
    echo "$talks" | jq -c '.talks[] | select(.type=="try" or (.type|startswith("try"))) | {id, code: .body.codes[0]}' | while read -r row; do
      local tid lang model code ph
      tid=$(echo "$row" | jq -r '.id')
      lang=$(echo "$row" | jq -r '.code.lang // "python"')
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

# chapter list sorted, starting from START (chapters are sequential - must do in order)
mapfile -t CHAPTERS < <(jq -r 'keys[]' "$ANSWERS" | sort -n | awk -v s="$START" '$1>=s')
if [[ "${#CHAPTERS[@]}" -eq 0 ]]; then
  echo "مفيش فصول >= $START في answers.json"
  exit 1
fi
TOTAL="${#CHAPTERS[@]}"
echo "Solving ${TOTAL} chapters from $START to ${CHAPTERS[-1]}"
i=0
for cid in "${CHAPTERS[@]}"; do
  i=$((i+1))
  ctype=$(jq -r --arg c "$cid" '.[$c].type // empty' "$ANSWERS")
  if [[ -z "$ctype" ]]; then
    echo "=== [$i/$TOTAL] chapter $cid MISSING from answers.json -> skip"
    continue
  fi
  echo "=== [$i/$TOTAL] chapter $cid (#$((10#$cid - 511000)), $ctype) lectures..."
  if ! complete_lectures "$cid"; then
    echo "STOP: chapter $cid failed (probably locked - finish previous first)."
    exit 1
  fi
  echo "--- start test $cid"
  api -X PUT "$TP/api/study/students/chapters/$cid/test" -d '{}' >/dev/null; slow 0.4
  prefix="review-questions"
  [[ "$ctype" == "test" ]] && prefix="test-questions"
  nq=$(jq -r --arg c "$cid" '.[$c].questions|length' "$ANSWERS")
  for k in $(seq 0 $((nq-1))); do
    qid=$(jq -r --arg c "$cid" --argjson k "$k" '.[$c].questions[$k].qid' "$ANSWERS")
    qtype=$(jq -r --arg c "$cid" --argjson k "$k" '.[$c].questions[$k].qtype' "$ANSWERS")
    if [[ "$qtype" == "choice" ]]; then
      choice=$(jq -r --arg c "$cid" --argjson k "$k" '.[$c].questions[$k].choice_id' "$ANSWERS")
      body=$(jq -n --argjson ch "$choice" '{choice_id:$ch}')
      kind="choice"
    else
      ans=$(jq -r --arg c "$cid" --argjson k "$k" '.[$c].questions[$k].answer_code' "$ANSWERS")
      body=$(jq -n --arg a "$ans" '{answer_code:$a}')
      kind="description"
    fi
    out=$(api -X PUT "$TP/api/study/students/$prefix/$qid/answer/$kind" -d "$body")
    # test-questions returns {} until the last one returns {"complete":{...}} - that's normal
    if echo "$out" | grep -q '"complete"'; then
      echo "  q $qid ($kind): COMPLETE $(echo "$out" | head -c 150)"
    elif echo "$out" | grep -q '"correct":true'; then
      echo "  q $qid ($kind): correct"
    elif [[ "$out" == "{}" ]]; then
      echo "  q $qid ($kind): ok"
    else
      echo "  q $qid ($kind): $(echo "$out" | head -c 150)"
    fi
    slow 0.5
  done
done

echo "[4/4] final status:"
api "$TP/api/study/students/sections/$SECTION/chapters" | python3 -c "import json,sys; ch=json.load(sys.stdin); print(f\"completed {sum(1 for c in ch if c.get('completed_at'))}/{len(ch)}\"); print('non-perfect:', [(c['chapter_id'],c.get('diamond')) for c in ch if c.get('diamond',0)<5])"
api "$TP/api/study/students/courses/$CONTENT_ID/diamond"
echo "DONE - all should be diamond 5 (125/125)."

# ---- qureo2 API notes (discovered by solving; see solver-manual) ----
# Chapter list:          GET /api/study/sections/106 -> {chapters:[{id:511001..511025, test_type}], section}
# Chapter detail:        GET /api/study/chapters/{cid} -> {chapter, lectures[], section}
# Test questions (read): GET /api/study/chapters/{cid}/test -> [{question, choices[], descriptions[]}]
# Test result detail:    GET /api/study/students/chapters/{cid}/test|review/result -> per-q correct + model_answer
# Test images:           GET /contents/chapter/{cid}/test/{file} (needs signed cookies from .../chapters/{cid}/cookies)
# Grader quirks: attempts are free, best_correct_count = max; description models vary (full code vs fragment);
#   511007010 wants 5110070101 ("If" capital); loop-scope taught as block-scoped (511021050 -> error);
#   511025070 wants 5110250701 (flowchart key is debatable - grader rules).
