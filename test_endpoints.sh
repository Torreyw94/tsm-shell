#!/bin/bash
# TSM-SHELL ENDPOINT AI LOGIC TESTER
# Tests all /api/* routes and reports pass/fail
# Run from: /workspaces/tsm-shell
# Usage: bash test_endpoints.sh [base_url]
# Default base URL: http://localhost:8080

BASE="${1:-http://localhost:8080}"
PASS=0
FAIL=0
ERRORS=()

green='\033[0;32m'
red='\033[0;31m'
yellow='\033[1;33m'
cyan='\033[0;36m'
reset='\033[0m'

header() {
  echo ""
  echo -e "${cyan}══════════════════════════════════════${reset}"
  echo -e "${cyan} $1${reset}"
  echo -e "${cyan}══════════════════════════════════════${reset}"
}

test_get() {
  local label="$1"
  local path="$2"
  local expect="$3"
  local res=$(curl -s "$BASE$path")
  if echo "$res" | grep -q "$expect"; then
    echo -e "${green}✅ GET $path${reset} → $label"
    PASS=$((PASS+1))
  else
    echo -e "${red}❌ GET $path${reset} → $label"
    echo "   Expected: $expect"
    echo "   Got: $(echo $res | head -c 200)"
    FAIL=$((FAIL+1))
    ERRORS+=("GET $path")
  fi
}

test_post() {
  local label="$1"
  local path="$2"
  local body="$3"
  local expect="$4"
  local res=$(curl -s -X POST "$BASE$path" \
    -H "Content-Type: application/json" \
    -d "$body")
  if echo "$res" | grep -q "$expect"; then
    echo -e "${green}✅ POST $path${reset} → $label"
    PASS=$((PASS+1))
  else
    echo -e "${red}❌ POST $path${reset} → $label"
    echo "   Expected: $expect"
    echo "   Got: $(echo $res | head -c 200)"
    FAIL=$((FAIL+1))
    ERRORS+=("POST $path")
  fi
}

echo ""
echo -e "${yellow}TSM-SHELL API ENDPOINT TEST${reset}"
echo -e "Base URL: ${cyan}$BASE${reset}"
echo -e "Started: $(date)"

# ── MUSIC ENGINE ──────────────────────────────────────────────────────────────
header "MUSIC ENGINE"
test_get  "engine state"           "/api/music/engine"              '"ok":true'
test_get  "activity feed"          "/api/music/activity"            '"ok":true'
test_get  "platform state"         "/api/music/platform"            '"ok":true'
test_get  "suite state"            "/api/music/state"               '"ok":true'
test_get  "evolution timeline"     "/api/music/evolution"           '"ok":true'
test_get  "dashboard sync"         "/api/music/dashboard-sync"      '"ok":true'
test_get  "billing state"          "/api/music/billing/state"       '"ok":true'
test_get  "monetization state"     "/api/music/monetization/state"  '"ok":true'
test_get  "revision state"         "/api/music/revision/state"      '"ok":true'

# ── MUSIC AGENT PASSES ────────────────────────────────────────────────────────
header "MUSIC AGENT PIPELINE"
test_post "single agent pass"      "/api/music/agent-pass" \
  '{"agent":"ZAY","draft":"Pain turned to power in the late night hours"}' \
  '"ok":true'

test_post "multi-agent chain"      "/api/music/chain" \
  '{"draft":"Pain turned to power in the late night hours","request":"Sharpen the hook"}' \
  '"ok":true'

test_post "strategy brief"         "/api/music/strategy" \
  '{"draft":"Pain turned to power"}' \
  '"ok":true'

# ── MUSIC DNA ─────────────────────────────────────────────────────────────────
header "MUSIC DNA + LEARNING"
test_post "save artist DNA"        "/api/music/dna/save" \
  '{"artist":"Test Artist","styleTerms":["pain","resilience"],"weights":{"cadence":0.9}}' \
  '"ok":true'

test_post "learn song into DNA"    "/api/music/song/learn" \
  '{"title":"Test Song","lyrics":"Pain turned to power in the late night hours\nStill I rise when the pressure hits"}' \
  '"ok":true'

test_post "DNA learn (engine)"     "/api/music/dna/learn" \
  '{"title":"Test Draft","draft":"Wrong all around me but I still move right"}' \
  '"ok":true'

# ── MUSIC REVISIONS ───────────────────────────────────────────────────────────
header "MUSIC REVISIONS"
test_post "generate revisions"     "/api/music/revision/generate" \
  '{"draft":"Pain turned to power","request":"Give me 3 options"}' \
  '"ok":true'

# ── MUSIC SESSIONS + EXPORT ───────────────────────────────────────────────────
header "MUSIC SESSIONS + EXPORT"
test_post "save session"           "/api/music/session/save" \
  '{"artist":"Test Artist","title":"Test Session","draft":"Pain turned to power","output":"Polished output"}' \
  '"ok":true'

test_get  "get artist session"     "/api/music/session/test-artist" '"ok":true'

test_post "export"                 "/api/music/export" \
  '{"artist":"Test Artist","title":"Test Export","output":"Pain turned to power in the late night hours"}' \
  '"ok":true'

test_post "generate 10 hooks"      "/api/music/hooks/generate10" \
  '{"artist":"Test Artist","draft":"Pain turned to power"}' \
  '"ok":true'

# ── MUSIC BILLING ─────────────────────────────────────────────────────────────
header "MUSIC BILLING"
test_post "upgrade intent"         "/api/music/billing/upgrade-intent" \
  '{"tier":"tier1","reason":"test"}' \
  '"ok":true'

test_post "set tier (dev)"         "/api/music/billing/set-tier-dev" \
  '{"tier":"tier1"}' \
  '"ok":true'

# ── STATIC ROUTES ─────────────────────────────────────────────────────────────
header "STATIC ROUTES"
test_get  "root index"             "/"                              'TSM'
test_get  "hub"                    "/html/hub/"                    'TSM Hub'
test_get  "schools command"        "/schools-command.html"          'TSM School Command Center'
test_get  "mortgage command"       "/mortgage-command.html"         'TSM'
test_get  "healthcare command"     "/healthcare-command.html"       'TSM'

# ── SUMMARY ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${cyan}══════════════════════════════════════${reset}"
echo -e " RESULTS: ${green}$PASS passed${reset} · ${red}$FAIL failed${reset}"
echo -e "${cyan}══════════════════════════════════════${reset}"

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo -e "${red}Failed endpoints:${reset}"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
fi

echo ""
