#!/usr/bin/env bash
# FinOps Suite · AI Logic Test Runner (fixed)
# Usage: GROQ_API_KEY=gsk_xxx ./test-ai.sh [--app=all|strategist|docengine|compliance|tax] [--verbose]
set -eo pipefail

APP="all"; VERBOSE=false; MODEL="llama-3.1-8b-instant"
for arg in "$@"; do
  case $arg in
    --app=*)   APP="${arg#*=}" ;;
    --model=*) MODEL="${arg#*=}" ;;
    --verbose) VERBOSE=true ;;
    gsk_*)     GROQ_API_KEY="$arg" ;;
  esac
done

KEY="${GROQ_API_KEY:-}"
[[ -z "$KEY" ]] && { echo "No GROQ_API_KEY. Usage: GROQ_API_KEY=gsk_xxx ./test-ai.sh"; exit 1; }

GROQ="https://api.groq.com/openai/v1/chat/completions"
PASS=0; FAIL=0; SKIP=0
TMP=$(mktemp /tmp/finops_test_XXXXXX.json)
trap 'rm -f $TMP' EXIT

G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'
C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'; B='\033[1m'

hr()  { echo -e "${C}──────────────────────────────────────────────${N}"; }
hdr() { echo -e "\n${B}${C}▸ $1${N}"; hr; }

run_test() {
  local label="$1" system="$2" user="$3" keyword="$4" max="${5:-300}"
  local mode="TEST"
  [[ -n "$keyword" ]] && mode="CHECK"
  echo -ne "  ${W}[${mode}]${N} ${label}... "

  # Build JSON payload safely via python3 — no nested shell quoting
  python3 - <<PYEOF > "$TMP"
import json, sys
payload = {
    "model": "$MODEL",
    "max_tokens": $max,
    "messages": [
        {"role": "system", "content": """$system"""},
        {"role": "user",   "content": """$user"""}
    ]
}
print(json.dumps(payload))
PYEOF

  local t0=$SECONDS
  local resp
  resp=$(curl -sf -X POST "$GROQ" \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d @"$TMP" 2>/dev/null || echo '{"error":{"message":"curl failed"}}')
  local elapsed=$(( SECONDS - t0 ))

  local content tokens
  content=$(python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
if 'error' in d:
    print('ERR:'+d['error']['message'][:100])
else:
    print(d['choices'][0]['message']['content'])
" <<< "$resp" 2>/dev/null || echo "ERR:parse failed")

  tokens=$(python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
u=d.get('usage',{})
print(str(u.get('prompt_tokens',0))+'p+'+str(u.get('completion_tokens',0))+'c')
" <<< "$resp" 2>/dev/null || echo "?")

  if [[ "$content" == ERR:* ]]; then
    echo -e "${R}FAIL${N} (${elapsed}s) — ${content#ERR:}"
    FAIL=$(( FAIL + 1 )); return
  fi

  if [[ -n "$keyword" ]]; then
    if echo "$content" | grep -qiE "$keyword"; then
      echo -e "${G}PASS${N} (${elapsed}s · ${tokens} · keyword matched)"
      PASS=$(( PASS + 1 ))
    else
      echo -e "${R}FAIL${N} (${elapsed}s · keyword not found)"
      $VERBOSE && echo -e "    ${W}Response: ${content:0:200}${N}"
      FAIL=$(( FAIL + 1 ))
    fi
  else
    echo -e "${G}PASS${N} (${elapsed}s · ${tokens})"
    $VERBOSE && echo -e "    ${C}$(echo "$content" | head -3)${N}"
    PASS=$(( PASS + 1 ))
  fi
}

# ═══════════════════════════════════════════════════
echo ""
echo -e "${B}${C}╔═══════════════════════════════════════════════════╗"
echo -e "║  FinOps Suite · AI Logic Test Runner              ║"
echo -e "║  Model : ${MODEL}$(printf '%*s' $(( 42 - ${#MODEL} )) '')║"
echo -e "║  App   : ${APP}$(printf '%*s' $(( 44 - ${#APP} )) '')║"
echo -e "╚═══════════════════════════════════════════════════╝${N}"

# 0 · Connectivity
hdr "0. Groq API Connectivity"
echo -ne "  [PING] Groq API... "
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $KEY" \
  "https://api.groq.com/openai/v1/models")
if [[ "$HTTP" == "200" ]]; then
  echo -e "${G}OK${N}"; PASS=$(( PASS + 1 ))
else
  echo -e "${R}FAIL (HTTP ${HTTP})${N}"; exit 1
fi

# 1 · Strategist
if [[ "$APP" == "all" || "$APP" == "strategist" ]]; then
  hdr "1. FinOps Main Strategist · BNCA Engine"
  S="You are the FinOps Main Strategist AI (Node 03). Generate concise executive controller reports. Be structured and action-oriented."

  sleep 1
  run_test "BNCA report generation" "$S" \
    "Generate a BNCA controller report. Data: AR 18.4K risk, 12 AP invoices, 6 security gaps, ZT 67/100, Form 990 84%, W-9 gaps 3 vendors. Format: RISK SUMMARY, P1/P2/P3 ACTIONS, 30-DAY OUTLOOK." \
    "" 400

  sleep 1
  run_test "P1 action detection" "$S" \
    "Highest priority action: AR 18.4K aging 97 days, 6 access gaps, Zero Trust 67/100?" \
    "P1|priority|immediate|critical|escalat" 150

  sleep 1
  run_test "ZT WATCH directive" "$S" \
    "Zero Trust score 67/100, 6 open access gaps, 2 unauthorized QB roles. Controller directive?" \
    "revok|access|QB|permission|watch|security" 150

  sleep 1
  run_test "Month-end BNCA synthesis" "$S" \
    "BNCA for: month-end close 84%, 3 bank recon items open, HRSA grant 480K tracked, Form 990 16% outstanding." \
    "" 300
fi

# 2 · Doc Engine
if [[ "$APP" == "all" || "$APP" == "docengine" ]]; then
  hdr "2. 4-Engine Doc Analysis"
  DOC="VENDOR INVOICE INV-2024-0891 | Vendor: Westside Holdings LLC | Amount: 4200.00 | Due: 2024-01-15 (97 days overdue) | Status: UNPAID — credit hold flagged | PO: PO-8821"

  sleep 1
  run_test "Engine 01 — Triage & Flag" \
    "You are Engine 01: Document Triage. Analyze financial docs. Output: DOCUMENT TYPE, CRITICAL FLAGS, ROUTE, RISK LEVEL." \
    "Analyze and flag: $DOC" "" 300

  sleep 1
  run_test "Engine 02 — Variance & Risk" \
    "You are Engine 02: Variance and Risk Intelligence. Analyze payment timing, variances, credit risk." \
    "Variance and risk analysis: $DOC" "" 300

  sleep 1
  run_test "Engine 03 — Controller Action Plan" \
    "You are Engine 03: Controller Action Plan. Generate P1/P2/P3 actions." \
    "Action plan for: $DOC" \
    "P1|P2|immediate|action|priority" 300

  sleep 1
  run_test "Engine 04 — CFO Executive Intel" \
    "You are Engine 04: CFO Executive Intelligence. Executive financial summary with risk and recommendations." \
    "CFO brief for: $DOC" \
    "revenue|cash|risk|executive|financial" 300
fi

# 3 · Compliance
if [[ "$APP" == "all" || "$APP" == "compliance" ]]; then
  hdr "3. TSM Compliance Command"
  CS="You are TSM Compliance Command AI. Monitor HIPAA, SOX, SOC-2, GDPR, PCI-DSS, NIST, OIG/CMS, AML/KYC. Precise compliance analysis only."

  sleep 1
  run_test "SOX endpoint failure triage" "$CS" \
    "CRITICAL: SOX Mapping Endpoint Failure. Legacy interface critical. Penalty exposure 240K. Immediate remediation plan?" \
    "SOX|endpoint|restore|remedia|penalty" 350

  sleep 1
  run_test "HIPAA BAA gap" "$CS" \
    "2 business associates missing signed BAA agreements. PHI access not contractually protected. Implications and required actions?" \
    "BAA|business associate|PHI|HIPAA|sign" 200

  sleep 1
  run_test "OIG Exclusion Screening" "$CS" \
    "OIG Exclusion Screening 47 days overdue. 47 staff not screened. CMS penalty exposure active. Remediation brief?" \
    "OIG|screen|Medicare|Medicaid|CMS" 300

  sleep 1
  run_test "Full Compliance Audit report" "$CS" \
    "Full Compliance Audit TSM Enterprise Q2 2026. SOX offline, OIG 47 staff overdue, ISO A.12.6 patches over 90 days, HIPAA BAA 2 missing. Score 94%. Executive audit report." \
    "" 500

  sleep 1
  run_test "AML/KYC latency alert" "$CS" \
    "AML/KYC degraded — 150ms latency, 3 verifications blocked. Compliance risk and action timeline?" \
    "AML|KYC|latency|BSA|verif" 200
fi

# 4 · Tax
if [[ "$APP" == "all" || "$APP" == "tax" ]]; then
  hdr "4. AuditOps Pro · Tax Intelligence"
  TS="You are AuditOps Pro — AI Tax Intelligence Platform. Analyze tax situations across S-Corp, Real Estate, Retirement, International domains. Be precise and IRS-grounded."

  sleep 1
  run_test "S-Corp reasonable compensation" "$TS" \
    "S-Corp owner salary: 45000. Revenue: 380000. Industry median: 95000. Analyze reasonable compensation risk using IRS thresholds." \
    "reasonable|compensation|IRS|salary|risk" 350

  sleep 1
  run_test "QBI 199A pass-through" "$TS" \
    "S-Corp pass-through: 220000. W-2 wages: 55000. Taxable income: 285000. MFJ. QBI deduction eligibility under section 199A with wage limitation test?" \
    "QBI|199A|deduction|wage|limit" 300

  sleep 1
  run_test "Section 179 limit 2025" "$TS" \
    "Section 179 deduction limit for tax year 2025 and the phase-out threshold?" \
    "179|1,160,000|phase" 150

  sleep 1
  run_test "FIRPTA withholding" "$TS" \
    "Foreign person selling US real property. Sale price: 850000. FIRPTA withholding required? Rate and treaty exemptions?" \
    "FIRPTA|withhold|15|treaty|foreign" 300

  sleep 1
  run_test "R&D tax credit calculation" "$TS" \
    "Qualified research: 340000. W-2 wages research staff: 180000. Supplies: 22000. Contract research: 45000. R&D credit using regular and simplified methods?" \
    "credit|20|simplified|ASC|regular|research" 350
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""; hr
TOTAL=$(( PASS + FAIL ))
PCT=0
[[ $TOTAL -gt 0 ]] && PCT=$(( PASS * 100 / TOTAL ))
BAR=$(python3 -c "n=int($PCT/5); print('█'*n + '░'*(20-n))")
echo -e "  ${G}PASS${N}  $PASS    ${R}FAIL${N}  $FAIL    ${Y}SKIP${N}  $SKIP"
echo -e "  ${C}[${G}${BAR}${C}]${N} ${PCT}%"
echo ""
[[ $FAIL -eq 0 ]] \
  && echo -e "  ${G}${B}All tests passed.${N}" \
  || echo -e "  ${R}${B}${FAIL} test(s) failed — run with --verbose to inspect output.${N}"
echo ""
