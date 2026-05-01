#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

SERVER="server.js"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$SERVER" ] || { echo "Missing $SERVER in $(pwd)"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$SERVER" "$BACKUP_DIR/server.js.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8")

# 1) Add a simple state endpoint if missing
state_route = r"""
app.get('/api/hc/state', (req, res) => {
  try {
    const state = readJson(HC_NODE_STATE_FILE, {});
    res.json({ ok: true, state });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});
"""

if "app.get('/api/hc/state'" not in text:
    marker = "app.post('/api/hc/rollup'"
    if marker in text:
        text = text.replace(marker, state_route + "\n" + marker, 1)
    else:
        text += "\n\n" + state_route

# 2) Collect important API route blocks
route_names = [
    "/api/hc/state",
    "/api/hc/rollup",
    "/api/hc/rollup/brief",
    "/api/hc/alerts",
    "/api/hc/brief",
]

route_blocks = []
for route in route_names:
    m = re.search(rf"app\.(get|post)\('{re.escape(route)}'.*?\n\}};\n|app\.(get|post)\('{re.escape(route)}'.*?\n\}}\);", text, flags=re.S)
    if m:
        route_blocks.append(m.group(0))

# Remove duplicates of those route blocks from current positions
for block in route_blocks:
    text = text.replace(block, "")

# 3) Reinsert those route blocks immediately before static section
static_marker = "// ── STATIC"
if static_marker in text and route_blocks:
    insertion = "\n\n".join(route_blocks).strip() + "\n\n"
    text = text.replace(static_marker, insertion + static_marker, 1)

# 4) Ensure no generic frontend fallback intercepts API routes incorrectly
# If there is a frontend fallback, keep it LAST and api-safe.
fallback_pattern = re.compile(r"app\.use\(\(req,\s*res(?:,\s*next)?\)\s*=>\s*\{[\s\S]*?sendFile[\s\S]*?\}\);", re.S)
fallbacks = fallback_pattern.findall(text)
if fallbacks:
    # remove all such fallbacks
    text = fallback_pattern.sub("", text)
    safe_fallback = """
app.use((req, res) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ ok: false, error: 'API route not found' });
  }

  return res.sendFile(path.join(__dirname, req.path), (err) => {
    if (err) {
      return res.sendFile(path.join(__dirname, 'html', 'index.html'));
    }
  });
});
"""
    # place safe fallback before app.listen if present, otherwise append
    if "app.listen(" in text:
        text = text.replace("app.listen(", safe_fallback + "\n\napp.listen(", 1)
    else:
        text += "\n\n" + safe_fallback

p.write_text(text, encoding="utf-8")
print("patched server.js")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== ROUTE ORDER CHECK =="
grep -n "/api/hc/state\\|/api/hc/rollup\\|/api/hc/rollup/brief\\|/api/hc/alerts\\|/api/hc/brief\\|// ── STATIC" server.js || true

echo "== COMMIT =="
git add server.js
git commit -m "Fix HC API order and add state endpoint" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== RESEED LIVE DEMO DATA =="
curl -s -X POST https://tsm-shell.fly.dev/api/hc/nodes/operations \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "officeName":"Scottsdale Shea Office",
    "officeManager":"Dee Montee",
    "status":"ONLINE",
    "findings":"Intake delays + scheduling pressure are the main throughput blockers.",
    "summary":"Re-sequence intake coverage and clear queues older than 24 hours.",
    "queueDepth":31,
    "intakeBacklog":18,
    "staffingCoverage":86,
    "noShowRate":9.2
  }'
echo

curl -s -X POST https://tsm-shell.fly.dev/api/hc/nodes/billing \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "officeName":"Scottsdale Shea Office",
    "officeManager":"Dee Montee",
    "status":"ONLINE",
    "findings":"Billing lag and scrub queue pressure are slowing clean submission.",
    "summary":"Prioritize high-value denials and scrub aging claims first.",
    "denialRate":12.4,
    "claimLagDays":6,
    "arOver30":185000
  }'
echo

curl -s -X POST https://tsm-shell.fly.dev/api/hc/nodes/insurance \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "officeName":"Scottsdale Shea Office",
    "officeManager":"Dee Montee",
    "status":"ONLINE",
    "findings":"Prior auth delay remains the top denial driver.",
    "summary":"Escalate auths older than 48 hours.",
    "authBacklog":27,
    "authDelayHours":56,
    "pendingClaimsValue":240000
  }'
echo

echo "== VERIFY STATE =="
curl -s https://tsm-shell.fly.dev/api/hc/state
echo
echo "== VERIFY BRIEF =="
curl -s -X POST https://tsm-shell.fly.dev/api/hc/brief \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "audience":"cfo",
    "format":"email"
  }'
echo
echo "== VERIFY ROLLUP =="
curl -s -X POST https://tsm-shell.fly.dev/api/hc/rollup \
  -H "Content-Type: application/json" \
  -d '{"system":"HonorHealth","top_n":3}'
echo
echo "== VERIFY ALERTS =="
curl -s -X POST https://tsm-shell.fly.dev/api/hc/alerts \
  -H "Content-Type: application/json" \
  -d '{"system":"HonorHealth"}'
echo
echo "Open:"
echo "https://tsm-shell.fly.dev/html/healthcare/"
echo "https://tsm-shell.fly.dev/html/hc-strategist/"
echo "https://tsm-shell.fly.dev/html/honor-portal/"
