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

p = Path("server.js")
text = p.read_text(encoding="utf-8")

helpers = r"""
function buildSystemRollup(state = {}, system = '', topN = 3) {
  const grouped = {};

  for (const [nodeKey, node] of Object.entries(state || {})) {
    if (system && (node.system || '') !== system) continue;
    const loc = node.location || 'Unknown';
    if (!grouped[loc]) grouped[loc] = {};
    grouped[loc][nodeKey] = node;
  }

  const offices = Object.entries(grouped).map(([location, nodes]) => {
    const result = aggregateLayer2(nodes);
    const highestYieldLane =
      result.top?.[0]?.nodeKey
        ? result.top[0].nodeKey.charAt(0).toUpperCase() + result.top[0].nodeKey.slice(1)
        : 'Unassigned';

    const officeName =
      nodes.operations?.officeName ||
      nodes.billing?.officeName ||
      nodes.insurance?.officeName ||
      nodes.compliance?.officeName ||
      location;

    const officeManager =
      nodes.operations?.officeManager ||
      nodes.billing?.officeManager ||
      nodes.insurance?.officeManager ||
      nodes.compliance?.officeManager ||
      '';

    return {
      location,
      officeName,
      officeManager,
      revenueAtRisk: result.revenueAtRisk || 0,
      recoverable72h: result.recoverable72h || 0,
      recoverable30d: result.recoverable30d || 0,
      cashAcceleration14d: result.cashAcceleration14d || Math.round((result.recoverable30d || 0) * 0.7),
      highestYieldLane,
      top: result.top || []
    };
  }).sort((a, b) => b.revenueAtRisk - a.revenueAtRisk);

  const totals = offices.reduce((acc, office) => {
    acc.totalRevenueAtRisk += office.revenueAtRisk || 0;
    acc.totalRecoverable72h += office.recoverable72h || 0;
    acc.totalRecoverable30d += office.recoverable30d || 0;
    acc.totalCashAcceleration14d += office.cashAcceleration14d || 0;
    return acc;
  }, {
    totalRevenueAtRisk: 0,
    totalRecoverable72h: 0,
    totalRecoverable30d: 0,
    totalCashAcceleration14d: 0
  });

  const laneCounts = {};
  for (const office of offices) {
    const lane = office.highestYieldLane || 'Unassigned';
    laneCounts[lane] = (laneCounts[lane] || 0) + 1;
  }

  const topOffices = offices.slice(0, topN);

  const summary = [
    `${system || 'System'} currently has $${totals.totalRevenueAtRisk.toLocaleString()} at risk across ${offices.length} reporting office(s).`,
    `Near-term recoverable value is $${totals.totalRecoverable72h.toLocaleString()} in 72 hours and $${totals.totalCashAcceleration14d.toLocaleString()} in projected 14-day cash acceleration.`,
    topOffices.length
      ? `Highest-priority office is ${topOffices[0].officeName} (${topOffices[0].location}) with $${topOffices[0].revenueAtRisk.toLocaleString()} at risk and ${topOffices[0].highestYieldLane} as the highest-yield lane.`
      : `No reporting offices found.`
  ].join(' ');

  return {
    ...totals,
    offices,
    topOffices,
    laneCounts,
    summary
  };
}
"""

route = r"""
app.post('/api/hc/rollup', (req, res) => {
  try {
    const { system = '', top_n = 3 } = req.body || {};
    const state = readJson(HC_NODE_STATE_FILE, {});
    const rollup = buildSystemRollup(state, system, Number(top_n || 3));

    res.json({
      ok: true,
      system,
      ...rollup
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});
"""

if "function buildSystemRollup(" not in text:
  marker = "app.post('/api/hc/brief'"
  if marker in text:
    text = text.replace(marker, helpers + "\n" + marker, 1)
  else:
    text += "\n" + helpers + "\n"

if "app.post('/api/hc/rollup'" not in text:
  marker = "app.post('/api/hc/brief'"
  if marker in text:
    text = text.replace(marker, route + "\n\n" + marker, 1)
  else:
    text += "\n" + route + "\n"

p.write_text(text, encoding="utf-8")
print("patched server.js")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== COMMIT =="
git add server.js
git commit -m "Add multi-office rollup endpoint" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== TEST =="
cat <<'CMDS'
curl -X POST https://tsm-shell.fly.dev/api/hc/rollup \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "top_n":3
  }'
CMDS
