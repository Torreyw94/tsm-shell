#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

SERVER="$ROOT/server.js"
BACKUP_DIR="$ROOT/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"

[ -f "$SERVER" ] || { echo "Missing server.js"; exit 1; }

cp -f "$SERVER" "$BACKUP_DIR/server.js.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8")

new_route = r"""
app.post('/api/hc/ask', async (req,res)=>{
  try{
    const {query='',system='',location=''} = req.body||{};
    const state = readJson(HC_NODE_STATE_FILE,{});

    const nodes = Object.values(state).filter(n=>
      (!system || n.system===system) &&
      (!location || location==='All' || n.location===location)
    );

    if(nodes.length===0){
      return res.json({
        ok:true,
        content:`TOP ISSUE
No live node data available.

WHY IT MATTERS
The strategist is scoped correctly, but no matching node has reported data yet.

BEST NEXT COURSE OF ACTION
1. Post live node telemetry for the selected system/location
2. Re-run BNCA after node sync
3. Validate filtered node coverage

OWNER LANES
Operations · Billing · Insurance

CONFIDENCE
65%`
      });
    }

    const preferredOrder = ['operations','billing','insurance','compliance','medical','financial','pharmacy','legal','grants','vendors','taxprep'];

    nodes.sort((a,b)=>{
      const ai = preferredOrder.indexOf((a.nodeKey||'').toLowerCase());
      const bi = preferredOrder.indexOf((b.nodeKey||'').toLowerCase());
      const av = ai === -1 ? 999 : ai;
      const bv = bi === -1 ? 999 : bi;
      return av - bv;
    });

    const n = nodes[0];

    const queueDepth = n.queueDepth ?? 'N/A';
    const intakeBacklog = n.intakeBacklog ?? 'N/A';
    const staffingCoverage = n.staffingCoverage ?? 'N/A';
    const noShowRate = n.noShowRate ?? 'N/A';
    const bnca = n.bnca || 'Re-sequence intake coverage, clear aged queues, and rebalance shift coverage.';

    const output = `TOP ISSUE
${n.findings || 'Cross-lane operational drag is the primary issue.'}

SYSTEM
${n.system || system || 'General Healthcare'}

LOCATION
${n.location || location || 'All'}

WHY IT MATTERS
Queue depth ${queueDepth}, intake backlog ${intakeBacklog}, staffing ${staffingCoverage}%, and no-show rate ${noShowRate} are constraining throughput and delaying clean handoffs.

BEST NEXT COURSE OF ACTION
1. Re-sequence intake coverage immediately
2. Clear queues older than 24 hours
3. Rebalance scheduling blocks for the next shift

OWNER LANES
Operations · Front Desk · Scheduling

NODE BNCA
${bnca}

FOLLOW-UP WINDOW
24–72 hours

CONFIDENCE
92%`;

    return res.json({ok:true,content:output});

  }catch(e){
    return res.status(500).json({ok:false,error:e.message});
  }
});
"""

pattern = re.compile(r"app\.post\('/api/hc/ask'[\s\S]*?\n\}\);", re.MULTILINE)

if pattern.search(text):
    text = pattern.sub(new_route.strip(), text, count=1)
else:
    marker = "// ── SUITE BUILDER"
    if marker in text:
        text = text.replace(marker, new_route.strip() + "\n\n" + marker, 1)
    else:
        text += "\n\n" + new_route.strip() + "\n"

p.write_text(text, encoding="utf-8")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== GIT STATUS =="
git status --short

echo "== COMMIT =="
git add server.js
git commit -m "Force node-driven HC ask output" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== TEST 1: POST NODE DATA =="
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/nodes/operations \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"system\":\"HonorHealth\","
echo "    \"location\":\"Scottsdale - Shea\","
echo "    \"status\":\"ONLINE\","
echo "    \"findings\":\"Intake delays and scheduling pressure are the main throughput blockers.\","
echo "    \"summary\":\"Re-sequence intake coverage and clear queues older than 24 hours.\","
echo "    \"bnca\":\"Best Next Course of Action:\\n1. Re-sequence intake coverage for the morning wave.\\n2. Escalate unresolved queues older than 24 hours.\\n3. Rebalance scheduling blocks before tomorrow first shift.\","
echo "    \"staffingCoverage\":86,"
echo "    \"queueDepth\":31,"
echo "    \"noShowRate\":9.2,"
echo "    \"intakeBacklog\":18"
echo "  }'"

echo
echo "== TEST 2: ASK STRATEGIST =="
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/ask \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"query\":\"what is the main issue\",\"system\":\"HonorHealth\",\"location\":\"Scottsdale - Shea\"}'"
