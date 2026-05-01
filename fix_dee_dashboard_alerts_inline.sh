#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js "backups/server.js.inline_alerts.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Replace the broken helper call with inline alerts logic
if "buildHCAlerts({ system }, state)" in text:
    text = text.replace(
        "const alerts = buildHCAlerts({ system }, state);",
        """
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
"""
    )

p.write_text(text, encoding="utf-8")
print("✅ Replaced buildHCAlerts with inline logic")
PY

node -c server.js

git add server.js
git commit -m "Fix Dee dashboard alerts (inline logic, remove missing helper)" || true
git push origin main

fly deploy

echo "== TEST =="
curl -X POST https://tsm-shell.fly.dev/api/honor/dee/dashboard \
  -H "Content-Type: application/json" \
  -d '{"system":"HonorHealth"}'
