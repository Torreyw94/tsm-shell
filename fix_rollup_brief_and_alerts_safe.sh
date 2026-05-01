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

rollup_brief = r"""
app.post('/api/hc/rollup/brief', (req, res) => {
  try {
    const { system = '', audience = 'cfo', format = 'email', top_n = 3 } = req.body || {};
    const state = readJson(HC_NODE_STATE_FILE, {});
    const rollup = buildSystemRollup(state, system, Number(top_n || 3));
    const top = rollup.topOffices?.[0] || null;

    const brief = `Subject: ${system || 'Healthcare'} System Revenue Risk Update

Team,

Across ${system || 'the system'}, we are currently tracking $${Number(rollup.totalRevenueAtRisk || 0).toLocaleString()} in revenue at risk.

Primary exposure is concentrated at ${top?.officeName || 'N/A'}${top?.location ? ` (${top.location})` : ''}, with ${top?.highestYieldLane || 'Unassigned'} identified as the highest-yield recovery lane.

We expect:
• $${Number(rollup.totalRecoverable72h || 0).toLocaleString()} recoverable within 72 hours
• $${Number(rollup.totalCashAcceleration14d || 0).toLocaleString()} in 14-day cash acceleration

Root drivers include cross-lane pressure in billing, insurance, and operations.

Immediate actions underway:
1. Clear high-value backlog
2. Escalate auth delays >48h
3. Align intake, billing, and scheduling

We will continue monitoring and provide updates as recovery progresses.

— Operations Intelligence`;

    res.json({
      ok: true,
      system,
      audience,
      format,
      brief,
      ...rollup
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});
"""

alerts_route = r"""
app.post('/api/hc/alerts', (req, res) => {
  try {
    const { system = '' } = req.body || {};
    const state = readJson(HC_NODE_STATE_FILE, {});
    const alerts = [];

    Object.entries(state || {}).forEach(([nodeKey, n]) => {
      if (system && (n.system || '') !== system) return;

      if (n.denialRate != null && Number(n.denialRate) > 10) {
        alerts.push({
          type: 'DENIAL_SPIKE',
          severity: 'HIGH',
          nodeKey,
          location: n.location || 'Unknown',
          officeName: n.officeName || '',
          message: `${n.location || 'Unknown'}: denial rate ${n.denialRate}%`
        });
      }

      if (n.authDelayHours != null && Number(n.authDelayHours) > 48) {
        alerts.push({
          type: 'AUTH_DELAY',
          severity: 'HIGH',
          nodeKey,
          location: n.location || 'Unknown',
          officeName: n.officeName || '',
          message: `${n.location || 'Unknown'}: auth delay ${n.authDelayHours}h`
        });
      }

      if (n.queueDepth != null && Number(n.queueDepth) > 25) {
        alerts.push({
          type: 'QUEUE_PRESSURE',
          severity: 'MEDIUM',
          nodeKey,
          location: n.location || 'Unknown',
          officeName: n.officeName || '',
          message: `${n.location || 'Unknown'}: queue depth ${n.queueDepth}`
        });
      }

      if (n.revenueAtRisk != null && Number(n.revenueAtRisk) > 250000) {
        alerts.push({
          type: 'REVENUE_RISK',
          severity: 'HIGH',
          nodeKey,
          location: n.location || 'Unknown',
          officeName: n.officeName || '',
          message: `${n.location || 'Unknown'}: revenue at risk $${Number(n.revenueAtRisk).toLocaleString()}`
        });
      }
    });

    res.json({
      ok: true,
      system,
      count: alerts.length,
      alerts
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});
"""

if "app.post('/api/hc/rollup/brief'" not in text:
    marker = "app.post('/api/hc/rollup'"
    idx = text.find(marker)
    if idx != -1:
        # insert after existing rollup route block by finding next occurrence after it
        text += "\n\n" + rollup_brief
    else:
        text += "\n\n" + rollup_brief

if "app.post('/api/hc/alerts'" not in text:
    text += "\n\n" + alerts_route

p.write_text(text, encoding="utf-8")
print("patched server.js")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== CHECK ROUTES =="
grep -n "/api/hc/rollup/brief\\|/api/hc/alerts\\|/api/hc/rollup" server.js || true

echo "== COMMIT =="
git add server.js
git commit -m "Add rollup brief and alerts endpoints" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== TEST =="
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/rollup/brief -H \"Content-Type: application/json\" -d '{\"system\":\"HonorHealth\"}'"
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/alerts -H \"Content-Type: application/json\" -d '{\"system\":\"HonorHealth\"}'"
