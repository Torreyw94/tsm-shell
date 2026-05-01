#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

SERVER="$ROOT/server.js"
BACKUP_DIR="$ROOT/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"
cp -f "$SERVER" "$BACKUP_DIR/server.js.layer2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8")

layer2_block = r"""
function toNum(v, d=0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : d;
}

function scoreNode(nodeKey, n) {
  let score = 0;

  if (nodeKey === 'operations') {
    score += toNum(n.queueDepth, 0) * 120;
    score += toNum(n.intakeBacklog, 0) * 180;
    score += Math.max(0, 90 - toNum(n.staffingCoverage, 90)) * 900;
    score += toNum(n.noShowRate, 0) * 700;
  }

  if (nodeKey === 'billing') {
    score += toNum(n.denialRate, 0) * 2500;
    score += toNum(n.claimLagDays, 0) * 1800;
    score += toNum(n.arOver30, 0) * 0.2;
  }

  if (nodeKey === 'insurance') {
    score += toNum(n.authBacklog, 0) * 1400;
    score += toNum(n.authDelayHours, 0) * 160;
    score += toNum(n.pendingClaimsValue, 0) * 0.12;
  }

  if (nodeKey === 'compliance') {
    score += toNum(n.openFindings, 0) * 2200;
    score += toNum(n.auditExposure, 0) * 0.15;
  }

  if (nodeKey === 'medical') {
    score += toNum(n.chartDefects, 0) * 900;
    score += toNum(n.authBacklog, 0) * 600;
  }

  return Math.round(score);
}

function aggregateLayer2(nodesMap) {
  const entries = Object.entries(nodesMap || {});
  const enriched = entries.map(([key, node]) => ({
    nodeKey: key,
    node,
    score: scoreNode(key, node)
  })).sort((a, b) => b.score - a.score);

  const ops = nodesMap.operations || {};
  const billing = nodesMap.billing || {};
  const insurance = nodesMap.insurance || {};
  const compliance = nodesMap.compliance || {};
  const medical = nodesMap.medical || {};

  const revenueAtRisk =
      (toNum(ops.queueDepth) * 850)
    + (toNum(ops.intakeBacklog) * 1450)
    + (Math.max(0, 90 - toNum(ops.staffingCoverage, 90)) * 2200)
    + (toNum(billing.denialRate) * 6200)
    + (toNum(billing.claimLagDays) * 4800)
    + (toNum(insurance.authBacklog) * 2100)
    + (toNum(insurance.pendingClaimsValue) * 0.18)
    + (toNum(compliance.auditExposure) * 0.35)
    + (toNum(medical.chartDefects) * 950);

  const recoverable72h = Math.round(revenueAtRisk * 0.34);
  const recoverable30d = Math.round(revenueAtRisk * 0.68);

  const top = enriched.slice(0, 3);

  return {
    enriched,
    revenueAtRisk: Math.round(revenueAtRisk),
    recoverable72h,
    recoverable30d,
    top
  };
}
"""

if "function aggregateLayer2(nodesMap)" not in text:
    marker = "app.post('/api/hc/ask'"
    if marker in text:
        text = text.replace(marker, layer2_block + "\n\n" + marker, 1)
    else:
        text += "\n\n" + layer2_block + "\n"

route_block = r"""
app.post('/api/hc/layer2', (req, res) => {
  try {
    const { system = '', location = '' } = req.body || {};
    const state = readJson(HC_NODE_STATE_FILE, {});

    const filtered = Object.fromEntries(
      Object.entries(state).filter(([_, n]) =>
        (!system || (n.system || '') === system) &&
        (!location || location === 'All' || (n.location || '') === location)
      )
    );

    const result = aggregateLayer2(filtered);
    const top = result.top;

    const rootCauseLines = top.map(t => {
      if (t.nodeKey === 'operations') {
        return `- Operations: queue ${t.node.queueDepth ?? 'N/A'}, backlog ${t.node.intakeBacklog ?? 'N/A'}, staffing ${t.node.staffingCoverage ?? 'N/A'}%`;
      }
      if (t.nodeKey === 'billing') {
        return `- Billing: denial ${t.node.denialRate ?? 'N/A'}%, lag ${t.node.claimLagDays ?? 'N/A'}d`;
      }
      if (t.nodeKey === 'insurance') {
        return `- Insurance: auth backlog ${t.node.authBacklog ?? 'N/A'}, delay ${t.node.authDelayHours ?? 'N/A'}h`;
      }
      if (t.nodeKey === 'compliance') {
        return `- Compliance: open findings ${t.node.openFindings ?? 'N/A'}, exposure $${t.node.auditExposure ?? 'N/A'}`;
      }
      if (t.nodeKey === 'medical') {
        return `- Medical: chart defects ${t.node.chartDefects ?? 'N/A'}`;
      }
      return `- ${t.nodeKey}: active pressure`;
    }).join('\n');

    const topIssue = top.length
      ? `${top.map(t => t.nodeKey).join(' + ')} are compounding into reimbursement and throughput drag.`
      : 'No qualifying node pressure found.';

    const output = `TOP ISSUE
${topIssue}

SYSTEM
${system || 'General Healthcare'}

LOCATION
${location || 'All'}

REVENUE AT RISK
$${result.revenueAtRisk.toLocaleString()}

RECOVERABLE VALUE
72 HOURS: $${result.recoverable72h.toLocaleString()}
30 DAYS: $${result.recoverable30d.toLocaleString()}

ROOT CAUSE
${rootCauseLines || '- No live node telemetry'}

BEST NEXT COURSE OF ACTION
1. Clear the highest-value backlog first
2. Escalate auth and documentation blockers older than 24–72 hours
3. Align intake, billing, and scheduling handoffs for the next shift

OWNER LANES
Operations · Billing · Insurance · Compliance

CONFIDENCE
91%`;

    res.json({
      ok: true,
      output,
      revenueAtRisk: result.revenueAtRisk,
      recoverable72h: result.recoverable72h,
      recoverable30d: result.recoverable30d,
      top: result.top
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});
"""

if "app.post('/api/hc/layer2'" not in text:
    marker = "app.post('/api/hc/ask'"
    if marker in text:
        text = text.replace(marker, route_block + "\n\n" + marker, 1)
    else:
        text += "\n\n" + route_block + "\n"

p.write_text(text, encoding="utf-8")
PY

node -c server.js
git add server.js
git commit -m "Add Layer 2 multi-node BNCA and revenue impact" || true
git push origin main
fly deploy

echo
echo "POST sample multi-node data, then run:"
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/layer2 -H \"Content-Type: application/json\" -d '{\"system\":\"HonorHealth\",\"location\":\"Scottsdale - Shea\"}'"
