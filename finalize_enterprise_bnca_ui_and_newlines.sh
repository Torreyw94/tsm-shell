#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

SERVER="server.js"
UI="html/hc-strategist/index.html"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$SERVER" ] || { echo "Missing $SERVER"; exit 1; }
[ -f "$UI" ] || { echo "Missing $UI"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$SERVER" "$BACKUP_DIR/server.js.$STAMP.bak"
cp -f "$UI" "$BACKUP_DIR/hc-strategist.index.html.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

server = Path("server.js")
ui = Path("html/hc-strategist/index.html")

# --- Patch server.js ---
s = server.read_text(encoding="utf-8")

# Final newline fix for Layer 2 root cause
s = s.replace("}).join('\\\\n');", "}).join('\\n');")

server.write_text(s, encoding="utf-8")

# --- Patch strategist UI ---
h = ui.read_text(encoding="utf-8")

# Stronger loading indicator
h = h.replace(
    "out.textContent = '> Running enterprise BNCA...';",
    "out.innerHTML = '⏳ Running enterprise BNCA...';"
)

# Pretty render output with line breaks
h = h.replace(
    "out.textContent = data.output || 'No enterprise BNCA output returned.';",
    "out.innerHTML = (data.output || 'No enterprise BNCA output returned.').replace(/\\n/g, '<br>');"
)

# Pretty render error too
h = h.replace(
    "out.textContent = '> Enterprise BNCA error: ' + err.message;",
    "out.innerHTML = '&gt; Enterprise BNCA error: ' + err.message;"
)

ui.write_text(h, encoding="utf-8")
print("patched server.js and html/hc-strategist/index.html")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== GIT DIFF =="
git diff -- server.js html/hc-strategist/index.html || true

echo "== COMMIT =="
git add server.js html/hc-strategist/index.html
git commit -m "Finalize enterprise BNCA output and strategist UI polish" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== RESEED NODES AFTER DEPLOY =="
cat <<'CMDS'
curl -X POST https://tsm-shell.fly.dev/api/hc/nodes/operations \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "status":"ONLINE",
    "findings":"Intake delays and scheduling pressure are the main throughput blockers.",
    "summary":"Re-sequence intake coverage and clear queues older than 24 hours.",
    "bnca":"Re-sequence intake coverage, escalate aged queues, rebalance next shift.",
    "staffingCoverage":86,
    "queueDepth":31,
    "noShowRate":9.2,
    "intakeBacklog":18
  }'

curl -X POST https://tsm-shell.fly.dev/api/hc/nodes/billing \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "status":"ONLINE",
    "denialRate":12.4,
    "claimLagDays":6,
    "arOver30":185000
  }'

curl -X POST https://tsm-shell.fly.dev/api/hc/nodes/insurance \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "status":"ONLINE",
    "authBacklog":27,
    "authDelayHours":56,
    "pendingClaimsValue":240000
  }'
CMDS

echo
echo "== TEST LAYER 2 =="
cat <<'CMDS'
curl -X POST https://tsm-shell.fly.dev/api/hc/layer2 \
  -H "Content-Type: application/json" \
  -d '{"system":"HonorHealth","location":"Scottsdale - Shea"}'
CMDS

echo
echo "== DEMO LINE =="
echo 'We are identifying $266K at risk and showing how to recover $127K in 14 days from actual operational pressure, not a static report.'
