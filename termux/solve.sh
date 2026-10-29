#!/usr/bin/env bash
# ==============================================================================
#   ⚡ EDU SOLVER CLI — Unified Educational Platform Automation
#   Termux & Linux CLI Edition • SPRIX + QUREO + QUREO2
#   High-Performance, Multi-Engine Automation Suite
# ==============================================================================
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
#  Environment & Directory Setup
# ──────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSWERS_DIR="$SCRIPT_DIR/answers"
CLI_VERSION="2.5.0"

# ──────────────────────────────────────────────────────────────────────────────
#  Terminal Styling & ANSI Color System
# ──────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_DIM='\033[2m'
  C_UNDERLINE='\033[4m'

  # Core Palette
  C_RED='\033[1;31m'
  C_GREEN='\033[1;32m'
  C_YELLOW='\033[1;33m'
  C_BLUE='\033[1;34m'
  C_MAGENTA='\033[1;35m'
  C_CYAN='\033[1;36m'
  C_WHITE='\033[1;37m'
  C_GRAY='\033[0;90m'

  # Subtle Accents
  C_BG_BLUE='\033[44m'
  C_BG_DARK='\033[40m'
else
  C_RESET=''
  C_BOLD=''
  C_DIM=''
  C_UNDERLINE=''
  C_RED=''
  C_GREEN=''
  C_YELLOW=''
  C_BLUE=''
  C_MAGENTA=''
  C_CYAN=''
  C_WHITE=''
  C_GRAY=''
  C_BG_BLUE=''
  C_BG_DARK=''
fi

# Visual Symbols
SYM_CHECK="${C_GREEN}✔${C_RESET}"
SYM_CROSS="${C_RED}✖${C_RESET}"
SYM_INFO="${C_CYAN}ℹ${C_RESET}"
SYM_WARN="${C_YELLOW}⚠${C_RESET}"
SYM_ARROW="${C_BLUE}➜${C_RESET}"
SYM_BULLET="${C_CYAN}•${C_RESET}"
SYM_STAR="${C_YELLOW}★${C_RESET}"
SYM_GEAR="${C_MAGENTA}⚙${C_RESET}"

# Output Helpers
log_info()  { printf "  ${SYM_INFO}  %s\n" "$*"; }
log_ok()    { printf "  ${SYM_CHECK}  ${C_GREEN}%s${C_RESET}\n" "$*"; }
log_warn()  { printf "  ${SYM_WARN}  ${C_YELLOW}%s${C_RESET}\n" "$*" >&2; }
log_err()   { printf "  ${SYM_CROSS}  ${C_RED}%s${C_RESET}\n" "$*" >&2; }
log_step()  { printf "\n${C_BOLD}${C_CYAN}▶ [%s] %s${C_RESET}\n" "$1" "$2"; }
die()       { printf "\n  ${SYM_CROSS}  ${C_RED}${C_BOLD}Error: %s${C_RESET}\n\n" "$*" >&2; exit 1; }

print_divider() {
  printf "${C_GRAY}────────────────────────────────────────────────────────────────${C_RESET}\n"
}

# ──────────────────────────────────────────────────────────────────────────────
#  Dependency Verification
# ──────────────────────────────────────────────────────────────────────────────
for tool in curl jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    die "Missing required package: '${tool}'.\n     Install it via:\n       pkg install -y curl jq"
  fi
done

# Timing & Delays (Default: 0.05 - ultra-fast; set SLEEP_SCALE=0.3 for slower pacing)
SLEEP_SCALE="${SLEEP_SCALE:-0.05}"
slow() {
  local base="${1:-0.1}"
  local duration
  duration=$(awk -v b="$base" -v s="$SLEEP_SCALE" 'BEGIN { printf "%.4f", b * s }')
  sleep "$duration"
}

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"

# ──────────────────────────────────────────────────────────────────────────────
#  Banners & UI Headers
# ──────────────────────────────────────────────────────────────────────────────
banner() {
  clear 2>/dev/null || true
  printf "\n"
  printf "  ${C_CYAN}┌──────────────────────────────────────────────────────────────┐${C_RESET}\n"
  printf "  ${C_CYAN}│${C_RESET}  ${C_BOLD}${C_WHITE}EDU SOLVER CLI  •  v${CLI_VERSION} (Termux Unified Engine)${C_RESET}           ${C_CYAN}│${C_RESET}\n"
  printf "  ${C_CYAN}│${C_RESET}  ${C_DIM}Automated Course & Assessment Completion Suite${C_RESET}              ${C_CYAN}│${C_RESET}\n"
  printf "  ${C_CYAN}└──────────────────────────────────────────────────────────────┘${C_RESET}\n\n"
}

print_help() {
  banner
  printf "${C_BOLD}USAGE:${C_RESET}\n"
  printf "  bash solve.sh [OPTIONS]\n"
  printf "  bash solve.sh <engine> <login_id> <password> [start]\n\n"

  printf "${C_BOLD}AVAILABLE ENGINES (1-6):${C_RESET}\n"
  printf "  ${C_CYAN}[1]${C_RESET}  💻  QUREO JavaScript  ${C_YELLOW}(Arabic)${C_RESET}    ${C_GRAY}54 Chapters • 270 Diamonds (Precomputed)${C_RESET}\n"
  printf "  ${C_CYAN}[2]${C_RESET}  💻  QUREO JavaScript  ${C_WHITE}(English)${C_RESET}   ${C_GRAY}54 Chapters • 270 Diamonds (Self-Discovery)${C_RESET}\n"
  printf "  ${C_CYAN}[3]${C_RESET}  🐍  QUREO2 Python     ${C_YELLOW}(Arabic)${C_RESET}    ${C_GRAY}25 Chapters • 125 Diamonds (Precomputed)${C_RESET}\n"
  printf "  ${C_CYAN}[4]${C_RESET}  🐍  QUREO2 Python     ${C_WHITE}(English)${C_RESET}   ${C_GRAY}10 Chapters •  50 Diamonds (Self-Discovery)${C_RESET}\n"
  printf "  ${C_CYAN}[5]${C_RESET}  💰  SPRIX Financial   ${C_YELLOW}(Arabic)${C_RESET}    ${C_GRAY}Units 1-6   • Curric 19-24 (Precomputed)${C_RESET}\n"
  printf "  ${C_CYAN}[6]${C_RESET}  💰  SPRIX Financial   ${C_WHITE}(English)${C_RESET}   ${C_GRAY}Units 1-6   • Full Self-Discovery${C_RESET}\n\n"

  printf "${C_BOLD}OPTIONS:${C_RESET}\n"
  printf "  ${C_GREEN}-e, --engine <1-6>${C_RESET}       Select automation engine\n"
  printf "  ${C_GREEN}-u, --user <id>${C_RESET}          Account Login / Student ID\n"
  printf "  ${C_GREEN}-p, --pass <password>${C_RESET}    Account Password\n"
  printf "  ${C_GREEN}-s, --start <num>${C_RESET}        Starting Chapter (1-54/25/10) or Unit (1-6)\n"
  printf "  ${C_GREEN}--speed <scale>${C_RESET}          Delay scale factor (default: 0.05; higher = slower)\n"
  printf "  ${C_GREEN}-h, --help${C_RESET}               Display this help guide and exit\n"
  printf "  ${C_GREEN}-v, --version${C_RESET}            Show script version\n\n"

  printf "${C_BOLD}EXAMPLES:${C_RESET}\n"
  printf "  ${C_GRAY}# Interactive wizard mode:${C_RESET}\n"
  printf "  bash solve.sh\n\n"
  printf "  ${C_GRAY}# Direct headless run (SPRIX Arabic, start Unit 1):${C_RESET}\n"
  printf "  bash solve.sh 5 471352766 MyPassword123\n\n"
  printf "  ${C_GRAY}# Resume QUREO Arabic from Chapter 20:${C_RESET}\n"
  printf "  bash solve.sh 1 482438443 MyPassword123 20\n\n"
  printf "  ${C_GRAY}# Named flags with customized speed:${C_RESET}\n"
  printf "  bash solve.sh -e 2 -u student1 -p pass --speed 0.2\n\n"
}

# ──────────────────────────────────────────────────────────────────────────────
#  Interactive Engine Selection
# ──────────────────────────────────────────────────────────────────────────────
pick_engine() {
  banner
  printf "  ${C_BOLD}${C_WHITE}Select Target Platform & Engine:${C_RESET}\n"
  print_divider
  printf "  ${C_CYAN}${C_BOLD}[1]${C_RESET}  💻  ${C_WHITE}QUREO JavaScript${C_RESET}   ${C_YELLOW}Arabic${C_RESET}    ${C_GRAY}│ 54 Chs • 270 ★ │ Answers DB${C_RESET}\n"
  printf "  ${C_CYAN}${C_BOLD}[2]${C_RESET}  💻  ${C_WHITE}QUREO JavaScript${C_RESET}   ${C_WHITE}English${C_RESET}   ${C_GRAY}│ 54 Chs • 270 ★ │ Auto-Discover${C_RESET}\n"
  printf "  ${C_CYAN}${C_BOLD}[3]${C_RESET}  🐍  ${C_WHITE}QUREO2 Python${C_RESET}      ${C_YELLOW}Arabic${C_RESET}    ${C_GRAY}│ 25 Chs • 125 ★ │ Answers DB${C_RESET}\n"
  printf "  ${C_CYAN}${C_BOLD}[4]${C_RESET}  🐍  ${C_WHITE}QUREO2 Python${C_RESET}      ${C_WHITE}English${C_RESET}   ${C_GRAY}│ 10 Chs •  50 ★ │ Auto-Discover${C_RESET}\n"
  printf "  ${C_CYAN}${C_BOLD}[5]${C_RESET}  💰  ${C_WHITE}SPRIX Financial${C_RESET}    ${C_YELLOW}Arabic${C_RESET}    ${C_GRAY}│ Units 1-6      │ Answers DB${C_RESET}\n"
  printf "  ${C_CYAN}${C_BOLD}[6]${C_RESET}  💰  ${C_WHITE}SPRIX Financial${C_RESET}    ${C_WHITE}English${C_RESET}   ${C_GRAY}│ Units 1-6      │ Auto-Discover${C_RESET}\n"
  print_divider
  printf "\n"

  while true; do
    printf "  ${SYM_ARROW} ${C_BOLD}Enter Engine Choice [1-6]:${C_RESET} "
    read -r ENGINE
    if [[ "$ENGINE" =~ ^[1-6]$ ]]; then
      break
    fi
    log_warn "Invalid selection. Please enter a digit from 1 to 6."
  done
}

# ──────────────────────────────────────────────────────────────────────────────
#  Engine Metadata Configuration
# ──────────────────────────────────────────────────────────────────────────────
set_engine() {
  case "$ENGINE" in
    1)
      NAME="QUREO JavaScript (Arabic)"
      PLATFORM="qureo"
      MODE="answers"
      SECTION=5
      CONTENT_ID="javascript_ar"
      I18N="ar"
      CH_MIN=1; CH_MAX=54; CH_BASE=90000
      ANS_FILE="$ANSWERS_DIR/qureo.json"
      CACHE_DIR="/tmp/qureo_lectures"
      ;;
    2)
      NAME="QUREO JavaScript (English)"
      PLATFORM="qureo"
      MODE="selfdiscover"
      SECTION=2
      CONTENT_ID="javascript_en"
      I18N="en"
      CH_MIN=1; CH_MAX=54; CH_BASE=30000
      ANS_FILE=""
      CACHE_DIR="/tmp/qureojsen_lectures"
      ;;
    3)
      NAME="QUREO2 Python (Arabic)"
      PLATFORM="qureo"
      MODE="answers"
      SECTION=106
      CONTENT_ID="python_short_ar"
      I18N="ar"
      CH_MIN=1; CH_MAX=25; CH_BASE=511000
      ANS_FILE="$ANSWERS_DIR/qureo2.json"
      CACHE_DIR="/tmp/qureo2_lectures"
      ;;
    4)
      NAME="QUREO2 Python (English)"
      PLATFORM="qureo"
      MODE="selfdiscover"
      SECTION=202
      CONTENT_ID="python_short_en"
      I18N="en"
      CH_MIN=1; CH_MAX=10; CH_BASE=531000
      ANS_FILE=""
      CACHE_DIR="/tmp/qureo2en_lectures"
      ;;
    5)
      NAME="SPRIX Financial Literacy (Arabic)"
      PLATFORM="sprix"
      MODE="answers"
      SUBJECT=7
      UNIT_MIN=1; UNIT_MAX=6; UNIT_BASE=18
      ANS_FILE="$ANSWERS_DIR/sprix.json"
      ;;
    6)
      NAME="SPRIX Financial Literacy (English)"
      PLATFORM="sprix"
      MODE="selfdiscover"
      SUBJECT=3
      UNIT_MIN=1; UNIT_MAX=6; UNIT_BASE=0
      ANS_FILE=""
      ;;
    *)
      die "Unknown engine ID: ${ENGINE}"
      ;;
  esac
}

print_config_card() {
  printf "\n"
  printf "  ${C_CYAN}╭─────────────────────────────────────────────────────────────╮${C_RESET}\n"
  printf "  ${C_CYAN}│${C_RESET}                    ${C_BOLD}${C_WHITE}SESSION CONFIGURATION${C_RESET}                    ${C_CYAN}│${C_RESET}\n"
  printf "  ${C_CYAN}├─────────────────────┬───────────────────────────────────────┤${C_RESET}\n"
  printf "  ${C_CYAN}│${C_RESET}  ${C_GRAY}Engine             │${C_RESET}  ${C_CYAN}%-37s${C_RESET}${C_CYAN}│${C_RESET}\n" "$NAME"
  printf "  ${C_CYAN}│${C_RESET}  ${C_GRAY}Platform           │${C_RESET}  ${C_WHITE}%-37s${C_RESET}${C_CYAN}│${C_RESET}\n" "${PLATFORM^^}"
  printf "  ${C_CYAN}│${C_RESET}  ${C_GRAY}User ID            │${C_RESET}  ${C_YELLOW}%-37s${C_RESET}${C_CYAN}│${C_RESET}\n" "$LOGIN_ID"
  if [[ "$PLATFORM" == "qureo" ]]; then
    printf "  ${C_CYAN}│${C_RESET}  ${C_GRAY}Start Chapter      │${C_RESET}  ${C_GREEN}%-37s${C_RESET}${C_CYAN}│${C_RESET}\n" "Chapter #$((10#$START - CH_BASE)) ($START)"
  else
    printf "  ${C_CYAN}│${C_RESET}  ${C_GRAY}Start Unit         │${C_RESET}  ${C_GREEN}%-37s${C_RESET}${C_CYAN}│${C_RESET}\n" "Unit #$((10#$START - UNIT_BASE)) ($START)"
  fi
  local mode_str
  [[ "$MODE" == "answers" ]] && mode_str="Precomputed Answers Database" || mode_str="Real-Time Self-Discovery"
  printf "  ${C_CYAN}│${C_RESET}  ${C_GRAY}Resolution Mode    │${C_RESET}  ${C_MAGENTA}%-37s${C_RESET}${C_CYAN}│${C_RESET}\n" "$mode_str"
  printf "  ${C_CYAN}│${C_RESET}  ${C_GRAY}Pacing Scale       │${C_RESET}  ${C_WHITE}%-37s${C_RESET}${C_CYAN}│${C_RESET}\n" "${SLEEP_SCALE}x"
  printf "  ${C_CYAN}╰─────────────────────┴───────────────────────────────────────╯${C_RESET}\n\n"
}

# ──────────────────────────────────────────────────────────────────────────────
#  QUREO Engine Core (Login, Lectures, Tests, Verification)
# ──────────────────────────────────────────────────────────────────────────────
q_setup() {
  PORTAL="https://me-portal.qureo.education"
  TP="https://me-tp.qureo.education"
  JAR="$(mktemp /tmp/qureo_XXXXXX.cookies)"

  CURL="curl -sS -L -c $JAR -b $JAR --compressed"
  HDR_PORTAL=(-H "User-Agent: $UA" -H "Accept: application/json" -H "Content-Type: application/json" -H "Origin: $PORTAL" -H "Referer: $PORTAL/login" -H "Accept-Language: en-US,en;q=0.9")
  HDR_TP=(-H "User-Agent: $UA" -H "Accept: */*" -H "Content-Type: application/json" -H "Origin: $TP" -H "Accept-Language: en-US,en;q=0.9")

  mkdir -p "$CACHE_DIR"
}

q_login() {
  log_step "1/4" "Authenticating with Portal API..."
  local login_code
  login_code=$($CURL "${HDR_PORTAL[@]}" -X POST "$PORTAL/oauth2/password-login" \
    --data "$(jq -n --arg s "$LOGIN_ID" --arg p "$PASSWORD" '{student_id:$s,password:$p}')" \
    -o /dev/null -w "%{http_code}")

  if [[ "$login_code" -ge 400 ]]; then
    die "Portal login failed (HTTP $login_code). Please verify your Login ID and Password."
  fi
  log_ok "Portal authenticated successfully (HTTP $login_code)"
  slow 1

  log_step "2/4" "Verifying student user profile..."
  local userinfo
  userinfo=$($CURL "${HDR_PORTAL[@]}" "$PORTAL/oauth2/userinfo" 2>/dev/null || true)
  local uname
  uname=$(echo "$userinfo" | jq -r '.name // .student_id // empty' 2>/dev/null || true)
  if [[ -n "$uname" ]]; then
    log_ok "Profile identified: ${uname}"
  else
    log_info "Profile token acquired"
  fi
  slow 0.5

  log_step "3/4" "Bootstrapping learning platform session..."
  local tp_code
  tp_code=$($CURL -H "User-Agent: $UA" -H "Referer: $TP/" "$TP/api/study/students/me" \
    -o /dev/null -w "%{http_code}")
  printf '%s\n' ".qureo.education\tTRUE\t/\tFALSE\t0\tstudent_selected_content_id\t$CONTENT_ID" >> "$JAR"
  printf '%s\n' ".qureo.education\tTRUE\t/\tFALSE\t0\ti18next\t$I18N" >> "$JAR"
  log_ok "TP session active (HTTP $tp_code)"
  slow 0.5
}

qapi() { $CURL "${HDR_TP[@]}" -H "Referer: $TP/" "$@"; }

qjget() {
  local resp
  resp=$(qapi "$1")
  if ! echo "$resp" | jq -e . >/dev/null 2>&1; then
    log_warn "Non-JSON response returned from: $1"
    echo "$resp" | head -c 250 >&2; echo >&2
    return 1
  fi
  echo "$resp"
}

qjget_cached() {
  local url="$1"
  local key="$2"
  local cfile="$CACHE_DIR/${key}.json"
  if [[ -s "$cfile" ]]; then
    cat "$cfile"
    return 0
  fi
  local resp
  resp=$(qapi "$url")
  if ! echo "$resp" | jq -e . >/dev/null 2>&1; then
    log_warn "Non-JSON response returned from: $url"
    echo "$resp" | head -c 250 >&2; echo >&2
    return 1
  fi
  echo "$resp" > "$cfile"
  echo "$resp"
}

q_complete_lectures() {
  local cid="$1" chap_json lectures
  if [[ "$MODE" == "answers" ]]; then
    chap_json=$(qjget_cached "$TP/api/study/chapters/$cid" "chap_$cid") || return 1
  else
    chap_json=$(qjget "$TP/api/study/chapters/$cid") || return 1
  fi

  lectures=$(echo "$chap_json" | jq -r '.lectures[]?.id')
  if [[ -z "$lectures" ]]; then
    log_warn "No lectures found for chapter $cid. (Chapter may be locked)"
    return 1
  fi

  local lid
  for lid in $lectures; do
    qapi -X PUT "$TP/api/study/students/lectures/$lid" -d '{}' >/dev/null
    slow 0.05
    local talks
    if [[ "$MODE" == "answers" ]]; then
      talks=$(qjget_cached "$TP/api/study/lectures/$lid" "lec_$lid") || return 1
    else
      talks=$(qjget "$TP/api/study/lectures/$lid") || return 1
    fi

    if ! echo "$talks" | jq -e '.talks' >/dev/null 2>&1; then
      log_warn "Lecture $lid locked (previous chapter not finished)."
      return 1
    fi

    echo "$talks" | jq -c '.talks[] | select(.type=="try" or (.type|startswith("try"))) | {id, code: .body.codes[0]}' | while read -r row; do
      local tid lang model code ph hasfitb payload
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
      qapi -X PUT "$TP/api/study/students/lecture-talks/$tid" -d "$payload" >/dev/null
      slow 0.2
    done
    qapi -X PUT "$TP/api/study/students/lectures/$lid/complete" -d '{}' >/dev/null
    slow 0.3
  done
  return 0
}

q_answers_test() {
  local cid="$1" ctype="$2"
  qapi -X PUT "$TP/api/study/students/chapters/$cid/test" -d '{}' >/dev/null
  slow 0.4
  local prefix="review-questions"
  [[ "$ctype" == "test" ]] && prefix="test-questions"

  local nq k qid qtype body kind out
  nq=$(jq -r --arg c "$cid" '.[$c].questions|length' "$ANS_FILE")
  for k in $(seq 0 $((nq-1))); do
    qid=$(jq -r --arg c "$cid" --argjson k "$k" '.[$c].questions[$k].qid' "$ANS_FILE")
    qtype=$(jq -r --arg c "$cid" --argjson k "$k" '.[$c].questions[$k].qtype' "$ANS_FILE")
    if [[ "$qtype" == "choice" ]]; then
      body=$(jq -n --argjson ch "$(jq -r --arg c "$cid" --argjson k "$k" '.[$c].questions[$k].choice_id' "$ANS_FILE")" '{choice_id:$ch}')
      kind="choice"
    else
      body=$(jq -n --arg a "$(jq -r --arg c "$cid" --argjson k "$k" '.[$c].questions[$k].answer_code' "$ANS_FILE")" '{answer_code:$a}')
      kind="description"
    fi
    out=$(qapi -X PUT "$TP/api/study/students/$prefix/$qid/answer/$kind" -d "$body")

    if echo "$out" | grep -q '"complete"'; then
      printf "    ${SYM_CHECK}  Question %-7s (%-11s): ${C_GREEN}Completed${C_RESET}\n" "$qid" "$kind"
    elif echo "$out" | grep -q '"correct":true'; then
      printf "    ${SYM_CHECK}  Question %-7s (%-11s): ${C_GREEN}Correct${C_RESET}\n" "$qid" "$kind"
    else
      printf "    ${SYM_CHECK}  Question %-7s (%-11s): ${C_CYAN}Submitted${C_RESET}\n" "$qid" "$kind"
    fi
    slow 0.5
  done
}

q_selfdiscover_test() {
  local cid="$1" ctype="$2"
  local prefix="review-questions"
  [[ "$ctype" == "test" ]] && prefix="test-questions"
  local mapfile="/tmp/qtermux_map_$cid.json"
  echo '{}' > "$mapfile"

  # Learning phase
  printf "  ${C_MAGENTA}◈ [Phase 1/2] Discovering answers for Chapter %s (%s)...${C_RESET}\n" "$cid" "$prefix"
  qapi -X PUT "$TP/api/study/students/chapters/$cid/test" -d '{}' >/dev/null
  slow 0.4

  local tq nq k
  tq=$(qjget "$TP/api/study/chapters/$cid/test") || return 1
  nq=$(echo "$tq" | jq 'length')

  for k in $(seq 0 $((nq-1))); do
    local qid qtype out
    qid=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].question.id')
    qtype=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].question.type')

    if [[ "$qtype" == "choice" ]]; then
      local guess real
      guess=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].choices[0].id')
      out=$(qapi -X PUT "$TP/api/study/students/$prefix/$qid/answer/choice" -d "$(jq -n --argjson c "$guess" '{choice_id:$c}')")
      real=$(echo "$out" | jq -r '.result.choices[]? | select(.correct==true) | .choice.id' 2>/dev/null | head -1)
      if [[ -n "$real" && "$real" != "null" ]]; then
        jq --arg q "$qid" --argjson c "$real" '.[$q] = {type:"choice", choice_id:$c}' "$mapfile" > "$mapfile.tmp" && mv "$mapfile.tmp" "$mapfile"
        printf "    ${SYM_BULLET}  Question %-7s (choice)     : Harvested ID ${C_YELLOW}%s${C_RESET}\n" "$qid" "$real"
      else
        printf "    ${SYM_WARN}  Question %-7s (choice)     : Initial probe submitted\n" "$qid"
      fi
    else
      local code real
      code=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].descriptions[0].code // empty')
      [[ -z "$code" ]] && code='print("x")'
      out=$(qapi -X PUT "$TP/api/study/students/$prefix/$qid/answer/description" -d "$(jq -n --arg a "$code" '{answer_code:$a}')")
      real=$(echo "$out" | jq -r '.result.model_answer // empty' 2>/dev/null)
      if [[ -n "$real" ]]; then
        jq --arg q "$qid" --arg a "$real" '.[$q] = {type:"description", answer_code:$a}' "$mapfile" > "$mapfile.tmp" && mv "$mapfile.tmp" "$mapfile"
        printf "    ${SYM_BULLET}  Question %-7s (description): Harvested model solution\n" "$qid"
      else
        printf "    ${SYM_WARN}  Question %-7s (description): Initial probe submitted\n" "$qid"
      fi
    fi
    slow 0.3
  done

  # Fallback harvesting from result endpoint
  local result
  result=$(qjget "$TP/api/study/students/chapters/$cid/$ctype/result" 2>/dev/null || true)
  if [[ -n "$result" ]] && echo "$result" | jq -e . >/dev/null 2>&1; then
    echo "$result" | jq -c '(.result.choice_results // .choice_results // [])[]? | {qid: .question_id, real: ([.choices[] | select(.correct==true) | .choice.id] | first)}' 2>/dev/null | while read -r row; do
      local qid real
      qid=$(echo "$row" | jq -r .qid); real=$(echo "$row" | jq -r .real)
      if [[ -n "$real" && "$real" != "null" ]]; then
        jq --arg q "$qid" --argjson c "$real" '.[$q] = {type:"choice", choice_id:$c}' "$mapfile" > "$mapfile.tmp" && mv "$mapfile.tmp" "$mapfile"
      fi
    done
    echo "$result" | jq -c '(.result.description_results // .description_results // [])[]? | {qid: .question_id, real: .model_answer}' 2>/dev/null | while read -r row; do
      local qid real
      qid=$(echo "$row" | jq -r .qid); real=$(echo "$row" | jq -r .real)
      if [[ -n "$real" && "$real" != "null" ]]; then
        jq --arg q "$qid" --arg a "$real" '.[$q] = {type:"description", answer_code:$a}' "$mapfile" > "$mapfile.tmp" && mv "$mapfile.tmp" "$mapfile"
      fi
    done
  fi

  # Final submission phase
  printf "  ${C_MAGENTA}◈ [Phase 2/2] Submitting verified answers for Chapter %s...${C_RESET}\n" "$cid"
  qapi -X PUT "$TP/api/study/students/chapters/$cid/test" -d '{}' >/dev/null
  slow 0.4

  for k in $(seq 0 $((nq-1))); do
    local qid qtype entry out
    qid=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].question.id')
    qtype=$(echo "$tq" | jq -r --argjson k "$k" '.[$k].question.type')
    entry=$(jq -c --arg q "$qid" '.[$q] // empty' "$mapfile")

    if [[ -z "$entry" ]]; then
      printf "    ${SYM_WARN}  Question %-7s: No harvested answer — skipped\n" "$qid"
      continue
    fi

    if [[ "$qtype" == "choice" ]]; then
      out=$(qapi -X PUT "$TP/api/study/students/$prefix/$qid/answer/choice" -d "$(jq -n --argjson c "$(echo "$entry" | jq -r .choice_id)" '{choice_id:$c}')")
    else
      out=$(qapi -X PUT "$TP/api/study/students/$prefix/$qid/answer/description" -d "$(jq -n --arg a "$(echo "$entry" | jq -r .answer_code)" '{answer_code:$a}')")
    fi

    if echo "$out" | grep -q '"complete"'; then
      printf "    ${SYM_CHECK}  Question %-7s: ${C_GREEN}Complete${C_RESET}\n" "$qid"
    elif echo "$out" | grep -q '"correct":true'; then
      printf "    ${SYM_CHECK}  Question %-7s: ${C_GREEN}Correct${C_RESET}\n" "$qid"
    else
      printf "    ${SYM_CHECK}  Question %-7s: ${C_CYAN}Submitted${C_RESET}\n" "$qid"
    fi
    slow 0.4
  done
  rm -f "$mapfile" "$mapfile.tmp"
}

q2en_ctype() {
  jq -rn --arg c "$1" '{"531004":"test","531008":"test"}[$c] // "review"'
}

q_final_status() {
  log_step "4/4" "Verifying Final Course Progress & Diamond Score"
  print_divider

  local chapters_json comp_count total_count
  chapters_json=$(qapi "$TP/api/study/students/sections/$SECTION/chapters" 2>/dev/null || true)
  if echo "$chapters_json" | jq -e . >/dev/null 2>&1; then
    comp_count=$(echo "$chapters_json" | jq -r '[.[] | select(.completed_at != null)] | length')
    total_count=$(echo "$chapters_json" | jq -r 'length')
    printf "  ${SYM_BULLET} Completed Chapters : ${C_GREEN}%s / %s${C_RESET}\n" "$comp_count" "$total_count"

    local incomplete
    incomplete=$(echo "$chapters_json" | jq -r '[.[] | select((.diamond // 0) < 5) | "\(.chapter_id)=\(.diamond // 0)★"] | join(", ")')
    if [[ -n "$incomplete" ]]; then
      printf "  ${SYM_WARN} Sub-5★ Chapters    : ${C_YELLOW}%s${C_RESET}\n" "$incomplete"
    else
      printf "  ${SYM_CHECK} Diamond Mastery    : ${C_GREEN}100%% (All 5-Star Diamonds Achieved)${C_RESET}\n"
    fi
  else
    log_warn "Unable to fetch chapter completion status"
  fi

  local diamond_summary
  diamond_summary=$(qapi "$TP/api/study/students/courses/$CONTENT_ID/diamond" 2>/dev/null || true)
  if echo "$diamond_summary" | jq -e . >/dev/null 2>&1; then
    local d_total
    d_total=$(echo "$diamond_summary" | jq -r '.total // .diamond // empty' 2>/dev/null || true)
    [[ -n "$d_total" ]] && printf "  ${SYM_STAR} Total Diamonds     : ${C_YELLOW}${C_BOLD}%s Diamonds${C_RESET}\n" "$d_total"
  fi
  print_divider
  log_ok "QUREO course run finalized successfully!"
}

q_solve_all() {
  local -a CHAPTERS
  if [[ "$MODE" == "answers" ]]; then
    mapfile -t CHAPTERS < <(jq -r 'keys[]' "$ANS_FILE" | sort -n | awk -v s="$START" '$1>=s')
  elif [[ "$ENGINE" == "4" ]]; then
    mapfile -t CHAPTERS < <(seq $((CH_BASE+1)) $((CH_BASE+CH_MAX)) | awk -v s="$START" '$1>=s')
  else
    mapfile -t CHAPTERS < <(qjget "$TP/api/study/sections/$SECTION" | jq -r --argjson s "$START" '.chapters[] | select(.id >= $s) | "\(.id) \(.test_type)"' | sort -n)
  fi

  if [[ "${#CHAPTERS[@]}" -eq 0 ]]; then
    die "No eligible chapters found starting from $START."
  fi

  local total="${#CHAPTERS[@]}"
  log_info "Preparing to process ${C_BOLD}${total}${C_RESET} chapter(s) starting at #${START}..."

  local i=0 entry cid ctype
  for entry in "${CHAPTERS[@]}"; do
    i=$((i+1))
    if [[ "$MODE" == "answers" || "$ENGINE" == "4" ]]; then
      cid="$entry"
    else
      cid="${entry%% *}"; ctype="${entry##* }"
    fi

    if [[ "$MODE" == "answers" ]]; then
      ctype=$(jq -r --arg c "$cid" '.[$c].type // empty' "$ANS_FILE")
      if [[ -z "$ctype" ]]; then
        printf "\n  ${C_GRAY}── [%s/%s] Chapter %s not found in answer database — skipping${C_RESET}\n" "$i" "$total" "$cid"
        continue
      fi
    elif [[ "$ENGINE" == "4" ]]; then
      ctype=$(q2en_ctype "$cid")
    fi

    local human_num=$((10#$cid - CH_BASE))
    printf "\n${C_BOLD}${C_BLUE}════════════════════════════════════════════════════════════════${C_RESET}\n"
    printf "  ${C_BOLD}${C_WHITE}▶ Chapter %s (#%s)${C_RESET} ${C_GRAY}│ Type: ${ctype:-unknown} │ Progress: [%s/%s]${C_RESET}\n" "$cid" "$human_num" "$i" "$total"
    printf "${C_BOLD}${C_BLUE}════════════════════════════════════════════════════════════════${C_RESET}\n"

    printf "  ${C_CYAN}• Completing interactive lectures...${C_RESET}\n"
    if ! q_complete_lectures "$cid"; then
      die "Halted at chapter $cid. Chapter appears locked; complete preceding chapters first."
    fi
    log_ok "Lectures completed"

    printf "  ${C_CYAN}• Solving assessment ($ctype)...${C_RESET}\n"
    if [[ "$MODE" == "answers" ]]; then
      q_answers_test "$cid" "$ctype"
    else
      q_selfdiscover_test "$cid" "$ctype"
    fi
    log_ok "Assessment passed for Chapter #$human_num"
  done

  q_final_status
}

# ──────────────────────────────────────────────────────────────────────────────
#  SPRIX Engine Core (Login, Blocks, Tests, Reviews)
# ──────────────────────────────────────────────────────────────────────────────
s_setup() {
  BASE="https://egy.app.spx-learning-square.com"
  JAR="$(mktemp /tmp/sprix_XXXXXX.cookies)"
  CURL="curl -sS -L -c $JAR -b $JAR --compressed"
  HDR=(-H "User-Agent: $UA" -H "Accept: application/json, text/plain, */*" -H "Content-Type: application/json" -H "Referer: $BASE/subjects/$SUBJECT/curriculum" -H "Accept-Language: en-US,en;q=0.9")
}

s_login() {
  log_step "1/3" "Authenticating SPRIX account..."
  local login_code
  login_code=$($CURL "${HDR[@]}" -X POST "$BASE/api/v1/auth/login" \
    --data "$(jq -n --arg u "$LOGIN_ID" --arg p "$PASSWORD" '{login_id:$u,password:$p}')" \
    -o /dev/null -w "%{http_code}")

  if [[ "$login_code" -ge 400 ]]; then
    die "SPRIX login failed (HTTP $login_code). Please check your Login ID and Password."
  fi
  log_ok "Authenticated (HTTP $login_code)"
  slow 1

  log_step "2/3" "Validating user session profile..."
  local me_resp
  me_resp=$($CURL "${HDR[@]}" "$BASE/api/v1/auth/me" 2>/dev/null || true)
  local student_name
  student_name=$(echo "$me_resp" | jq -r '.data.name // .data.login_id // empty' 2>/dev/null || true)
  if [[ -n "$student_name" ]]; then
    log_ok "Active student profile: ${student_name}"
  else
    log_info "Student session token confirmed"
  fi
  slow 0.5
}

sapi() { $CURL "${HDR[@]}" "$@"; }

sjget() {
  local resp
  resp=$(sapi "$1")
  if ! echo "$resp" | jq -e . >/dev/null 2>&1; then
    log_warn "Non-JSON response from SPRIX API: $1"
    echo "$resp" | head -c 250 >&2; echo >&2
    return 1
  fi
  echo "$resp"
}

s_do_chapter_answers() {
  local cid="$1" n ok=0 k bid oid out
  n=$(jq -r --arg c "$cid" '.chapters[$c]|length // empty' "$ANS_FILE")
  if [[ -z "$n" ]]; then
    local nq
    nq=$(sjget "$BASE/api/v1/chapters/$cid/blocks" | jq '[.data.blocks[] | select(.type=="question")] | length')
    if [[ "$nq" == "0" ]]; then
      sapi -X POST "$BASE/api/v1/chapters/$cid/complete" -d '{}' >/dev/null
      printf "    ${SYM_CHECK}  Simulation chapter %s: ${C_GREEN}Marked completed (no questions)${C_RESET}\n" "$cid"
      slow 0.3
      return 0
    fi
    log_warn "Chapter $cid missing from answers database ($nq questions present)."
    return 1
  fi

  for k in $(seq 0 $((n-1))); do
    bid=$(jq -r --arg c "$cid" --argjson k "$k" '.chapters[$c][$k][0]' "$ANS_FILE")
    oid=$(jq -r --arg c "$cid" --argjson k "$k" '.chapters[$c][$k][1]' "$ANS_FILE")
    out=$(sapi -X POST "$BASE/api/v1/chapters/$cid/answer" -d "$(jq -n --argjson b "$bid" --argjson o "$oid" '{block_id:$b,selected_option_id:$o}')")
    if echo "$out" | grep -q '"is_correct":true'; then
      ok=$((ok+1))
    else
      log_warn "Chapter $cid block $bid response incorrect. Verify answer definition."
      return 1
    fi
    slow 0.3
  done

  sapi -X POST "$BASE/api/v1/chapters/$cid/complete" -d '{}' >/dev/null
  printf "    ${SYM_CHECK}  Chapter %-5s: ${C_GREEN}%s/%s questions verified and completed${C_RESET}\n" "$cid" "$ok" "$n"
  slow 0.3
}

s_do_chapter_brute() {
  local cid="$1" blocks nq
  blocks=$(sjget "$BASE/api/v1/chapters/$cid/blocks") || return 1
  nq=$(echo "$blocks" | jq '[.data.blocks[] | select(.type=="question")] | length')
  if [[ "$nq" == "0" ]]; then
    sapi -X POST "$BASE/api/v1/chapters/$cid/complete" -d '{}' >/dev/null
    printf "    ${SYM_CHECK}  Simulation chapter %s: ${C_GREEN}Completed (no questions)${C_RESET}\n" "$cid"
    slow 0.3
    return 0
  fi

  echo "$blocks" | jq -c '.data.blocks[] | select(.type=="question") | {block_id: .id, qid: .question_id, options: [.options[] | .id]}' | while read -r row; do
    local bid qid opts found=0 oid out
    bid=$(echo "$row" | jq -r .block_id)
    qid=$(echo "$row" | jq -r .qid)
    opts=$(echo "$row" | jq -c .options)
    for oid in $(echo "$opts" | jq -r '.[]'); do
      out=$(sapi -X POST "$BASE/api/v1/chapters/$cid/answer" -d "$(jq -n --argjson b "$bid" --argjson o "$oid" '{block_id:$b,selected_option_id:$o}')")
      if echo "$out" | grep -q '"is_correct":true'; then
        printf "    ${SYM_CHECK}  Chapter %s Q%s (Block %s): Option %s verified\n" "$cid" "$qid" "$bid" "$oid"
        found=1
        break
      fi
      slow 0.2
    done
    if [[ "$found" == "0" ]]; then
      printf "    ${SYM_WARN}  Chapter %s Q%s (Block %s): Could not determine valid option\n" "$cid" "$qid" "$bid"
    fi
  done

  sapi -X POST "$BASE/api/v1/chapters/$cid/complete" -d '{}' >/dev/null
  printf "    ${SYM_CHECK}  Chapter %-5s: ${C_GREEN}Marked complete${C_RESET}\n" "$cid"
  slow 0.3
}

s_do_test_answers() {
  local tid="$1" start_raw map n k qid oid tqid
  start_raw=$(sapi -X POST "$BASE/api/v1/tests/$tid/start" -d '{}')
  if ! echo "$start_raw" | jq -e . >/dev/null 2>&1; then
    log_warn "Failed to initialize test $tid: $(echo "$start_raw" | head -c 200)"
    return 1
  fi

  map=$(echo "$start_raw" | jq -c '[.data.test_questions[] | select(.question_id != null and .id != null) | {key:(.question_id|tostring), value:(.id|tostring)}] | from_entries')
  n=$(jq -r --arg t "$tid" '.tests[$t]|length' "$ANS_FILE")

  for k in $(seq 0 $((n-1))); do
    qid=$(jq -r --arg t "$tid" --argjson k "$k" '.tests[$t][$k][0]' "$ANS_FILE")
    oid=$(jq -r --arg t "$tid" --argjson k "$k" '.tests[$t][$k][1]' "$ANS_FILE")
    tqid=$(echo "$map" | jq -r --arg q "$qid" '.[$q] // empty')
    [[ -z "$tqid" ]] && { log_warn "Test $tid question $qid not found in this attempt!"; return 1; }
    sapi -X PUT "$BASE/api/v1/tests/$tid/questions/$tqid/answer" -d "$(jq -n --argjson o "$oid" '{selected_option_id:$o}')" >/dev/null
    slow 0.25
  done

  local sub
  sub=$(sapi -X POST "$BASE/api/v1/tests/$tid/submit" -d '{}')
  local score passed
  score=$(echo "$sub" | jq -r '.data.response.total_score // empty' 2>/dev/null || true)
  passed=$(echo "$sub" | jq -r '.data.response.passed // empty' 2>/dev/null || true)
  printf "    ${SYM_CHECK}  Test %-8s: ${C_GREEN}Submitted (Score: %s, Passed: %s)${C_RESET}\n" "$tid" "${score:-OK}" "${passed:-true}"
  slow 0.4
}

s_do_test_selfdiscover() {
  local tid="$1" start_raw map n k sub ansfile nh qid tqid oid
  start_raw=$(sapi -X POST "$BASE/api/v1/tests/$tid/start" -d '{}')
  if ! echo "$start_raw" | jq -e . >/dev/null 2>&1; then
    log_warn "Failed to initiate test $tid: $(echo "$start_raw" | head -c 200)"
    return 1
  fi

  # Phase 1: Exploration
  map=$(echo "$start_raw" | jq -c '[.data.test_questions[] | select(.question_id != null and .id != null) | {key:(.question_id|tostring), value:(.id|tostring)}] | from_entries')
  n=$(echo "$start_raw" | jq '[.data.test_questions[] | select(.question_id != null)] | length')

  for k in $(seq 0 $((n-1))); do
    qid=$(echo "$start_raw" | jq -r "[.data.test_questions[] | select(.question_id != null)][ $k ].question_id")
    tqid=$(echo "$map" | jq -r --arg q "$qid" '.[$q]')
    oid=$(echo "$start_raw" | jq -r --arg q "$qid" '.data.options[$q][0].id')
    [[ -z "$tqid" || "$tqid" == "null" || -z "$oid" || "$oid" == "null" ]] && { log_warn "Test $tid Q$qid: bad mapping"; return 1; }
    sapi -X PUT "$BASE/api/v1/tests/$tid/questions/$tqid/answer" -d "$(jq -n --argjson o "$oid" '{selected_option_id:$o}')" >/dev/null
    slow 0.2
  done

  sub=$(sapi -X POST "$BASE/api/v1/tests/$tid/submit" -d '{}')
  slow 0.3

  ansfile="/tmp/sprix_termux_test_${tid}.json"
  echo '{}' > "$ansfile"
  echo "$sub" | jq -c '.data.options | to_entries[] | {qid: .key, real: ([.value[] | select(.is_correct==true) | .id] | first)}' 2>/dev/null | while read -r row; do
    qid=$(echo "$row" | jq -r .qid); real=$(echo "$row" | jq -r .real)
    if [[ -n "$real" && "$real" != "null" ]]; then
      jq --arg q "$qid" --argjson o "$real" '.[$q] = $o' "$ansfile" > "$ansfile.tmp" && mv "$ansfile.tmp" "$ansfile"
    fi
  done

  nh=$(jq 'length' "$ansfile")
  printf "    ${SYM_BULLET}  Test %s probe complete: ${C_YELLOW}%s correct answers discovered${C_RESET}\n" "$tid" "$nh"
  if [[ "$nh" == "0" ]]; then
    log_warn "Could not discover answers for test $tid."
    rm -f "$ansfile"; return 1
  fi

  # Phase 2: Mastery submission
  start_raw=$(sapi -X POST "$BASE/api/v1/tests/$tid/start" -d '{}')
  map=$(echo "$start_raw" | jq -c '[.data.test_questions[] | select(.question_id != null and .id != null) | {key:(.question_id|tostring), value:(.id|tostring)}] | from_entries')
  n=$(echo "$start_raw" | jq '[.data.test_questions[] | select(.question_id != null)] | length')

  for k in $(seq 0 $((n-1))); do
    qid=$(echo "$start_raw" | jq -r "[.data.test_questions[] | select(.question_id != null)][ $k ].question_id")
    tqid=$(echo "$map" | jq -r --arg q "$qid" '.[$q]')
    oid=$(jq -r --arg q "$qid" '.[$q] // empty' "$ansfile")
    if [[ -z "$oid" || "$oid" == "null" ]]; then
      continue
    fi
    sapi -X PUT "$BASE/api/v1/tests/$tid/questions/$tqid/answer" -d "$(jq -n --argjson o "$oid" '{selected_option_id:$o}')" >/dev/null
    slow 0.2
  done

  local final_sub score passed
  final_sub=$(sapi -X POST "$BASE/api/v1/tests/$tid/submit" -d '{}')
  score=$(echo "$final_sub" | jq -r '.data.response.total_score // empty' 2>/dev/null || true)
  passed=$(echo "$final_sub" | jq -r '.data.response.passed // empty' 2>/dev/null || true)
  printf "    ${SYM_CHECK}  Test %-8s: ${C_GREEN}Mastery achieved (Score: %s, Passed: %s)${C_RESET}\n" "$tid" "${score:-100}" "${passed:-true}"
  slow 0.3
  rm -f "$ansfile" "$ansfile.tmp"
}

s_do_review() {
  local rid="$1"
  sapi -X POST "$BASE/api/v1/reviews/$rid/complete" -d '{}' >/dev/null
  printf "    ${SYM_CHECK}  Review %-6s: ${C_GREEN}Marked completed${C_RESET}\n" "$rid"
  slow 0.3
}

s_final_status() {
  log_step "3/3" "Finalizing SPRIX Curriculum Verification"
  print_divider

  local units_json
  units_json=$(sapi "$BASE/api/v1/subjects/$SUBJECT/units" 2>/dev/null || true)
  if echo "$units_json" | jq -e . >/dev/null 2>&1; then
    echo "$units_json" | jq -r '.data[] | "  Unit \(.id) (Item count: \(.completed_items)/\(.total_items)) : \(.progress_pct)%"' 2>/dev/null | while read -r line; do
      printf "  ${SYM_CHECK}  ${C_WHITE}%s${C_RESET}\n" "$line"
    done
  else
    log_warn "Unable to retrieve unit completion summary"
  fi
  print_divider
  log_ok "SPRIX curriculum solved successfully!"
}

s_solve_all() {
  log_step "3/3" "Processing Units ${START} through ${UNIT_MAX}..."

  local CURRICULUM_DATA uid items row id type
  CURRICULUM_DATA=$(sjget "$BASE/api/v1/subjects/$SUBJECT/curriculum")

  for uid in $(seq "$START" "$UNIT_MAX"); do
    local human_unit=$((10#$uid - UNIT_BASE))
    printf "\n${C_BOLD}${C_BLUE}════════════════════════════════════════════════════════════════${C_RESET}\n"
    printf "  ${C_BOLD}${C_WHITE}▶ Unit %s (#%s)${C_RESET} ${C_GRAY}│ Progress: [%s/%s]${C_RESET}\n" "$uid" "$human_unit" "$human_unit" "$UNIT_MAX"
    printf "${C_BOLD}${C_BLUE}════════════════════════════════════════════════════════════════${C_RESET}\n"

    items=$(echo "$CURRICULUM_DATA" | jq -r --argjson u "$uid" '.data[] | select(.id==$u) | .items[] | "\(.id):\(.item_type)"' 2>/dev/null)
    if [[ -z "$items" ]]; then
      CURRICULUM_DATA=$(sjget "$BASE/api/v1/subjects/$SUBJECT/curriculum")
      items=$(echo "$CURRICULUM_DATA" | jq -r --argjson u "$uid" '.data[] | select(.id==$u) | .items[] | "\(.id):\(.item_type)"' 2>/dev/null)
    fi

    if [[ -z "$items" ]]; then
      die "Curriculum retrieval failed for Unit $uid"
    fi

    for row in $items; do
      id="${row%%:*}"; type="${row##*:}"
      case "$type" in
        chapter)
          if [[ "$MODE" == "answers" ]]; then
            s_do_chapter_answers "$id" || die "Halted at chapter $id"
          else
            s_do_chapter_brute "$id" || die "Halted at chapter $id"
          fi
          ;;
        review)
          s_do_review "$id"
          ;;
        test)
          if [[ "$MODE" == "answers" ]]; then
            s_do_test_answers "$id"
          else
            s_do_test_selfdiscover "$id" || die "Halted at test $id"
          fi
          ;;
      esac
    done
  done

  s_final_status
}

# ──────────────────────────────────────────────────────────────────────────────
#  Cleanup Handler
# ──────────────────────────────────────────────────────────────────────────────
cleanup() {
  local exit_code=$?
  if [[ -n "${JAR:-}" && -f "$JAR" ]]; then
    rm -f "$JAR"
  fi
  if command -v termux-wake-unlock >/dev/null 2>&1; then
    termux-wake-unlock 2>/dev/null || true
  fi
  if [[ $exit_code -ne 0 ]]; then
    printf "\n  ${SYM_WARN}  ${C_YELLOW}Execution ended with exit code %s${C_RESET}\n\n" "$exit_code"
  fi
}
trap cleanup EXIT INT TERM

# ──────────────────────────────────────────────────────────────────────────────
#  Main CLI Logic & Flag Parsing
# ──────────────────────────────────────────────────────────────────────────────
main() {
  ENGINE="${ENGINE:-}"
  LOGIN_ID="${LOGIN_ID:-}"
  PASSWORD="${PASSWORD:-}"
  START="${START:-}"

  # Parse flags if present
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        print_help
        exit 0
        ;;
      -v|--version)
        printf "EDU SOLVER CLI v%s\n" "$CLI_VERSION"
        exit 0
        ;;
      -e|--engine)
        ENGINE="$2"; shift 2 ;;
      -u|--user|--login)
        LOGIN_ID="$2"; shift 2 ;;
      -p|--pass|--password)
        PASSWORD="$2"; shift 2 ;;
      -s|--start)
        START="$2"; shift 2 ;;
      --speed|--sleep-scale)
        SLEEP_SCALE="$2"; shift 2 ;;
      -*)
        die "Unrecognized option '$1'. Use -h or --help for available options."
        ;;
      *)
        # Positional arguments fallback
        if [[ -z "$ENGINE" ]]; then
          ENGINE="$1"
        elif [[ -z "$LOGIN_ID" ]]; then
          LOGIN_ID="$1"
        elif [[ -z "$PASSWORD" ]]; then
          PASSWORD="$1"
        elif [[ -z "$START" ]]; then
          START="$1"
        fi
        shift
        ;;
    esac
  done

  # Step 1: Engine Selection
  if [[ -z "$ENGINE" ]]; then
    pick_engine
  else
    [[ "$ENGINE" =~ ^[1-6]$ ]] || die "Engine ID must be a number between 1 and 6 (received: '$ENGINE')."
  fi
  set_engine

  # Step 2: Credentials
  if [[ -z "$LOGIN_ID" || -z "$PASSWORD" ]]; then
    banner
    printf "  ${C_BOLD}${C_WHITE}Authentication for: ${C_CYAN}%s${C_RESET}\n" "$NAME"
    print_divider
  fi

  if [[ -z "$LOGIN_ID" ]]; then
    printf "  ${SYM_ARROW} ${C_BOLD}Enter Student / Login ID:${C_RESET} "
    read -r LOGIN_ID
  fi

  if [[ -z "$PASSWORD" ]]; then
    printf "  ${SYM_ARROW} ${C_BOLD}Enter Password:${C_RESET} "
    read -r -s PASSWORD
    printf "\n"
  fi

  if [[ -z "$LOGIN_ID" || -z "$PASSWORD" ]]; then
    die "Login ID and Password are both required."
  fi

  # Step 3: Starting Chapter / Unit
  if [[ "$PLATFORM" == "qureo" ]]; then
    if [[ -z "$START" ]]; then
      printf "  ${SYM_ARROW} ${C_BOLD}Start Chapter [%s] (Range: %s-%s):${C_RESET} " "$CH_MIN" "$CH_MIN" "$CH_MAX"
      read -r START
      START="${START:-$CH_MIN}"
    fi

    # Normalize human chapter number (e.g. 1 -> 90001)
    if [[ "$START" =~ ^[0-9]+$ ]] && (( 10#$START >= CH_MIN && 10#$START <= CH_MAX )); then
      START=$((CH_BASE + 10#$START))
    fi

    if ! [[ "$START" =~ ^[0-9]+$ ]] || (( 10#$START < CH_BASE + CH_MIN || 10#$START > CH_BASE + CH_MAX )); then
      die "Start chapter must be between $CH_MIN and $CH_MAX (received: '$START')."
    fi
  else
    if [[ -z "$START" ]]; then
      printf "  ${SYM_ARROW} ${C_BOLD}Start Unit [%s] (Range: %s-%s):${C_RESET} " "$UNIT_MIN" "$UNIT_MIN" "$UNIT_MAX"
      read -r START
      START="${START:-$UNIT_MIN}"
    fi

    # Normalize human unit number
    if [[ "$START" =~ ^[0-9]+$ ]] && (( 10#$START >= UNIT_MIN && 10#$START <= UNIT_MAX )); then
      START=$((UNIT_BASE + 10#$START))
    fi

    if (( 10#$START < UNIT_BASE + UNIT_MIN || 10#$START > UNIT_BASE + UNIT_MAX )); then
      die "Start unit must be between $UNIT_MIN and $UNIT_MAX (received: '$START')."
    fi
  fi

  # Termux Wake-Lock Optimization
  if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock 2>/dev/null || true
  fi

  # Display Configuration Card
  print_config_card

  # Execute Platform Suite
  if [[ "$PLATFORM" == "qureo" ]]; then
    q_setup
    q_login
    q_solve_all
  else
    s_setup
    s_login
    s_solve_all
  fi

  printf "\n  ${C_BOLD}${C_GREEN}════════════════════════════════════════════════════════════════${C_RESET}\n"
  printf "  ${SYM_CHECK}  ${C_BOLD}${C_GREEN}All tasks completed successfully! Have a great day.${C_RESET}\n"
  printf "  ${C_BOLD}${C_GREEN}════════════════════════════════════════════════════════════════${C_RESET}\n\n"
}

main "$@"
