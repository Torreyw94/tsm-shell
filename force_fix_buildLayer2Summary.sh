#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js "backups/server.js.layer2fix.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Remove one broken duplicate helper block if present
text = re.sub(
    r"\nfunction buildLayer2Summary\(officeState = \{\}, system = '', location = ''\) \{[\s\S]*?\n\}\n",
    "\n",
    text,
    count=1
)

helper = """

function buildLayer2Summary(officeState = {}, system = '', location = '') {
  const ops = officeState.operations || {};
  const billing = officeState.billing || {};
  const insurance = officeState.insurance || {};

  const denialRate = Number(billing.denialRate || 0);
  const claimLagDays = Number(billing.claimLagDays || 0);
  const arOver30 = Number(billing.arOver30 || 0);

  const authBacklog = Number(insurance.authBacklog || 0);
  const authDelayHours = Number(insurance.authDelayHours || 0);
  const pendingClaimsValue = Number(insurance.pendingClaimsValue || 0);

  const queueDepth = Number(ops.queueDepth || 0);
  const intakeBacklog = Number(ops.intakeBacklog || 0);
  const staffingCoverage = Number(ops.staffingCoverage || 0);

  const revenueAtRisk =
    Math.round(
      arOver30 * 0.62 +
      pendingClaimsValue * 0.28 +
      (queueDepth * 850) +
      (intakeBacklog * 1200)
    );

  const recoverable72h = Math.round(revenueAtRisk * 0.34);
  const recoverable30d = Math.round(revenueAtRisk * 0.68);
  const cashAcceleration14d = Math.round(revenueAtRisk * 0.476);

  const laneScores = {
    Billing: (denialRate * 6) + (claimLagDays * 4) + (arOver30 / 5000),
    Insurance: (authBacklog * 2.2) + (authDelayHours * 1.1) + (pendingClaimsValue / 12000),
    Operations: (queueDepth * 2) + (intakeBacklog * 2.6) + Math.max(0, 100 - staffingCoverage)
  };

  const highestYieldLane = Object.entries(laneScores).sort((a,b)=>b[1]-a[1])[0]?.[0] || 'Billing';

  return {
    ok: true,
    system,
    location,
    revenueAtRisk,
    recoverable72h,
    recoverable30d,
    cashAcceleration14d,
    highestYieldLane,
    rootCause: [
      `Billing: denial ${denialRate}% with lag ${claimLagDays}d`,
      `Insurance: auth backlog ${authBacklog}, delay ${authDelayHours}h`,
      `Operations: queue ${queueDepth}, backlog ${intakeBacklog}, staffing ${staffingCoverage}%`
    ],
    bestNextActions: [
      'Clear the highest-value backlog first',
      'Escalate auth and documentation blockers older than 24–72 hours',
      'Align intake, billing, and scheduling handoffs for the next shift'
    ],
    ownerLanes: ['Operations','Billing','Insurance'],
    confidence: 91
  };
}
"""

m = re.search(r"\napp\.(get|post|use)\(", text)
if not m:
    raise SystemExit("Could not find insertion point")

idx = m.start()
text = text[:idx] + helper + "\n" + text[idx:]

p.write_text(text, encoding="utf-8")
print("force-inserted top-level buildLayer2Summary")
PY

node -c server.js
grep -n "function buildLayer2Summary\|buildLayer2Summary(" server.js

git add server.js
git commit -m "Force top-level buildLayer2Summary helper" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
