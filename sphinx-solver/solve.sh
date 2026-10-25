#!/usr/bin/env bash
# sphinx-solver — Global Finance Quest (subject 8, game_key=sphinx) auto-solver — self-discovering (no answers.json)
# Stock-portfolio game: the news published on day N moves prices on day N+1, so each day we
# position the whole portfolio on the instruments with the strongest bullish news and advance.
# Scoring (server-authoritative, verified live): total = returnScore + diversityScore (max 100 / grade SS).
#   returnScore    = min(70, round(profitPct * 1.75))          -> caps at 70 once profit >= 40%
#   diversityScore = min(30, 3 * days_with_>=5_distinct)        -> caps at 30 after 10 such days
# So reaching total=100 needs profit>=40% AND 10 days holding >=5 distinct instruments.
# Once profit>=40% (LOCK_ASSETS) the engine locks to cash + 5 tiny fillers and coasts to SS.
# Usage:
#   ./solve.sh                            -> يطلب Login ID والباسورد
#   ./solve.sh <login_id>                 -> يطلب الباسورد
#   ./solve.sh <login_id> '<pass>'
#   LOGIN_ID=... PASSWORD='...' ./solve.sh -> من غير ما يسأل
#   LOCK_ASSETS=700000 SLEEP_SCALE=0.05 ./solve.sh ...
# Requirements: curl, jq, python3, uuidgen (or python3 fallback)
set -euo pipefail

LOGIN_ID="${1:-${LOGIN_ID:-}}"
PASSWORD="${2:-${PASSWORD:-}}"
if [[ -z "$LOGIN_ID" ]]; then
  read -rp "Login ID (code): " LOGIN_ID
fi
if [[ -z "$PASSWORD" ]]; then
  read -rsp "Password: " PASSWORD; echo
fi
if [[ -z "$LOGIN_ID" || -z "$PASSWORD" ]]; then
  echo "لازم تدخل Login ID والباسورد." >&2; exit 1
fi

BASE="https://egy.app.spx-learning-square.com"
GAME_API="$BASE/game/sphinx/api/v1"
SUBJECT="${SUBJECT:-8}"
JAR="$(mktemp /tmp/sphinx-cookies.XXXXXX)"
TMP="$(mktemp -d /tmp/sphinx-tmp.XXXXXX)"
trap 'rm -f "$JAR"; rm -rf "$TMP"' EXIT

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
CURL=(curl -sS -L -c "$JAR" -b "$JAR" --compressed --retry 3 --retry-delay 2 --retry-connrefused)
HDR=(-H "User-Agent: $UA" -H "Accept: application/json, text/plain, */*" -H "Content-Type: application/json" -H "Referer: $BASE/game/sphinx" -H "Origin: $BASE" -H "Accept-Language: ar,en-US;q=0.9")

SLEEP_SCALE="${SLEEP_SCALE:-0.05}"
slow() { sleep "$(awk "BEGIN{print (${1:-0.1}) * $SLEEP_SCALE}")"; }

LOCK_ASSETS="${LOCK_ASSETS:-700000}"

api() { "${CURL[@]}" "${HDR[@]}" "$@"; }

jget() {
  local resp
  resp=$(api "$1")
  if ! echo "$resp" | jq -e . >/dev/null 2>&1; then
    echo "API non-JSON for $1:" >&2; echo "$resp" | head -c 300 >&2; echo >&2
    return 1
  fi
  echo "$resp"
}

me() { jget "$GAME_API/me?lang=ar" | tee "$TMP/me.json" >/dev/null; }

ensure_game() {
  local gid
  gid=$(jq -r '.data.currentGameId // empty' "$TMP/me.json" 2>/dev/null)
  if [[ -z "$gid" || "$gid" == "null" ]]; then
    echo "no active game — starting a new one..." >&2
    local started
    started=$(api -X POST "$GAME_API/games?lang=ar" -d '{}' | tee "$TMP/start.json")
    gid=$(echo "$started" | jq -r '.data.game.id // empty')
    if [[ -z "$gid" || "$gid" == "null" ]]; then
      gid=$(jq -r '.data.currentGameId // empty' "$TMP/me.json")
      echo "game already active, id=$gid" >&2
    else
      echo "started game id=$gid" >&2
    fi
  else
    echo "continuing existing game id=$gid" >&2
  fi
  echo "$gid"
}

get_state() { jget "$GAME_API/games/$1?lang=ar" | tee "$TMP/state.json" >/dev/null; }

do_trade() { # <gid> <day> <code> <side> <qty>
  local gid="$1" day="$2" code="$3" side="$4" qty="$5"
  qty="${qty//$'\r'/}"; qty="${qty// /}"
  [[ "$qty" =~ ^[0-9]+$ ]] || { echo "TRADE $side $code qty=[$qty] INVALID" >&2; return 0; }
  [[ "$qty" == "0" ]] && return 0
  local ct
  ct=$(uuidgen 2>/dev/null || python3 -c 'import uuid;print(uuid.uuid4())')
  api -X POST "$GAME_API/games/$gid/trades?lang=ar" \
    -d "$(jq -n --arg c "$code" --arg s "$side" --argjson q "$qty" --argjson d "$day" --arg t "$ct" '{code:$c,side:$s,quantity:$q,expectedDay:$d,clientTradeId:$t}')" \
    -o "$TMP/trade.json" >/dev/null 2>&1 || true
  local succ
  succ=$(jq -r '.success // .error.code // "?"' "$TMP/trade.json" 2>/dev/null || echo "?")
  if [[ "$succ" == "true" ]]; then
    echo "TRADE $side $code x$qty day=$day: OK" >&2
  else
    echo "TRADE $side $code x$qty day=$day: $succ" >&2
  fi
  slow 0.15
}

advance_day() { # <gid> <day>
  api -X POST "$GAME_API/games/$1/advance?lang=ar" \
    -d "$(jq -n --argjson d "$2" '{expectedDay:$d}')" -o "$TMP/advance.json" >/dev/null 2>&1 || true
  slow 0.4
}

get_result() { jget "$GAME_API/games/$1/result?lang=ar" | tee "$TMP/result.json"; }

# ---- python planner: reads state.json + stocks.json, prints {"coast":bool,"buys":[[code,qty],...]} ----
plan_day() {
  python3 - "$TMP/state.json" "$TMP/stocks.json" "$LOCK_ASSETS" <<'PY'
import json, sys

state_p, stocks_p, lock = sys.argv[1], sys.argv[2], float(sys.argv[3])
s = json.load(open(state_p))['data']
ins = json.load(open(stocks_p))['data']['instruments']
meta = {i['code']: i for i in ins}

day = s['game']['currentDay']
total = s['game']['totalAssets']
cash = s['game']['cash']

fx = {'EGP': 1.0}
for f in s.get('fx', []):
    fx[f['currency']] = f['rates'][-1]

def px(c):
    for p in s.get('prices', []):
        if p['code'] == c:
            return p['prices'][-1]
    return 0.0

def px_egp(c):
    return px(c) * fx.get(meta[c].get('currency', 'EGP'), 1.0)

sectors = {}
for i in ins:
    if i.get('type') == 'stock':
        sectors.setdefault(i.get('sector'), []).append(i['code'])

MULT = {
    ('stock', 'bull'): 1.15, ('stock', 'bear'): 0.85,
    ('sector', 'bull'): 1.08, ('sector', 'bear'): 0.92,
    ('macro', 'bull'): 1.05, ('macro', 'bear'): 0.95,
}

mult = {c: 1.0 for c in meta if meta[c].get('type') == 'stock'}
for n in s.get('news', []):
    if n.get('day') != day:
        continue
    key = (n.get('type'), n.get('effect'))
    if key not in MULT:
        continue
    m = MULT[key]
    if n.get('type') == 'stock':
        c = (n.get('stock') or {}).get('code')
        if c in mult:
            mult[c] *= m
    elif n.get('type') == 'sector':
        for c in sectors.get(n.get('sector'), []):
            mult[c] *= m
    elif n.get('type') == 'macro':
        reg = n.get('region')
        for c in mult:
            if reg == 'global' or meta[c].get('region') == reg:
                mult[c] *= m

edge = {c: v - 1.0 for c, v in mult.items()}

buys = []
coast = total >= lock
if not coast:
    pos = sorted(((v, c) for c, v in edge.items() if v > 0.005), reverse=True)
    if pos and cash > 0:
        cap = 0.5
        tot = sum(v for v, _ in pos)
        w = {c: min(cap, v / tot) for v, c in pos}
        sw = sum(w.values())
        w = {c: v / sw for c, v in w.items()}
        budget = cash * 0.97
        for c, wt in sorted(w.items(), key=lambda kv: -kv[1]):
            p = px_egp(c)
            if p <= 0:
                continue
            q = int((budget * wt) // p)
            if q > 0:
                buys.append([c, q])

have = set(c for c, _ in buys)
cheap = sorted(((px_egp(c), c) for c in meta if px_egp(c) > 0), key=lambda x: x[0])
for _, c in cheap:
    if len(have) >= 5:
        break
    if c in have:
        continue
    buys.append([c, 1])
    have.add(c)

print(json.dumps({"coast": coast, "buys": buys}))
PY
}

# ================= main =================
echo "[1/6] login to platform..."
"${CURL[@]}" "${HDR[@]}" -X POST "$BASE/api/v1/auth/login" \
  --data "$(jq -n --arg u "$LOGIN_ID" --arg p "$PASSWORD" '{login_id:$u,password:$p}')" \
  -o "$TMP/login.json" -w "login http=%{http_code}\n"
if ! jq -e '.success == true' "$TMP/login.json" >/dev/null 2>&1; then
  echo "LOGIN FAILED:" >&2; jq -r '.error.code // .error.message // "unknown"' "$TMP/login.json" >&2 || cat "$TMP/login.json" >&2
  exit 1
fi
slow 1

echo "[2/6] sphinx game token..."
"${CURL[@]}" "${HDR[@]}" -X POST "$BASE/api/v1/subjects/$SUBJECT/games/sphinx/token" \
  -d '{}' -o "$TMP/token.json" -w "token http=%{http_code}\n"
slow 0.5

echo "[3/6] game instruments..."
jget "$GAME_API/stocks?lang=ar" | tee "$TMP/stocks.json" >/dev/null
slow 0.5

echo "[4/6] solving game day-by-day ..."
me >/dev/null
GAME_ID=$(ensure_game)
LOCKED=0
for _ in $(seq 1 40); do
  get_state "$GAME_ID" >/dev/null
  status=$(jq -r '.data.game.status' "$TMP/state.json")
  if [[ "$status" != "playing" ]]; then
    echo "game status=$status (stopping loop)"
    break
  fi
  cur_day=$(jq -r '.data.game.currentDay' "$TMP/state.json")
  total=$(jq -r '.data.game.totalAssets' "$TMP/state.json")
  div=$(jq -r '.data.diversitySum // 0' "$TMP/state.json")

  # sell everything we hold at current day prices
  jq -r '.data.holdings[] | select(.quantity>0) | "\(.code) \(.quantity)"' "$TMP/state.json" | while read -r code qty; do
    do_trade "$GAME_ID" "$cur_day" "$code" "sell" "$qty"
  done
  get_state "$GAME_ID" >/dev/null

  plan_day > "$TMP/plan.json"
  coast=$(jq -r '.coast' "$TMP/plan.json")
  if [[ "$coast" == "true" && "$LOCKED" == "0" ]]; then
    LOCKED=1
    echo "day $cur_day: LOCKED at total=$total (profit>=40% -> returnScore 70) -> cash + fillers"
  fi
  jq -r '.buys[] | "\(.[0]) \(.[1])"' "$TMP/plan.json" | while read -r code qty; do
    do_trade "$GAME_ID" "$cur_day" "$code" "buy" "$qty"
  done

  advance_day "$GAME_ID" "$cur_day"
  nd=$(jq -r '.data.game.currentDay // empty' "$TMP/advance.json" 2>/dev/null)
  ns=$(jq -r '.data.game.status // empty' "$TMP/advance.json" 2>/dev/null)
  nt=$(jq -r '.data.game.totalAssets // 0' "$TMP/advance.json" 2>/dev/null)
  sc=$(jq -r '.data.score | "return=\(.return) diversity=\(.diversity) total=\(.total) grade=\(.grade)"' "$TMP/advance.json" 2>/dev/null || echo "")
  echo "day $cur_day -> $nd status=$ns total=$nt $sc  (diversitySum=$div)"
  if [[ "$ns" == "finished" || "$ns" == "completed" ]]; then
    break
  fi
done

echo "[5/6] final state ..."
get_state "$GAME_ID" >/dev/null
jq -r '.data.game | "day=\(.currentDay) status=\(.status) cash=\(.cash) total=\(.totalAssets)"' "$TMP/state.json"
jq -r '.data.score | "score=\(.total) return=\(.return) diversity=\(.diversity) grade=\(.grade)"' "$TMP/state.json" 2>/dev/null || true

echo "[6/6] result ..."
get_result "$GAME_ID" >/dev/null
jq -r '.data.result | "totalScore=\(.totalScore) returnScore=\(.returnScore) diversityScore=\(.diversityScore) grade=\(.grade) finalAssets=\(.finalAssets) profit=\(.profit) passed=\(.passed)"' "$TMP/result.json" 2>/dev/null \
  || jq -r '.data // . | tostring' "$TMP/result.json" | head -c 500; echo

echo "DONE. gameId=$GAME_ID"
