#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js "backups/server.js.posture.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Remove one existing broken copy if present
text = re.sub(
    r"\nfunction buildStrategistSystemPosture\(system, officesPayload = \[\]\) \{[\s\S]*?\n\}\n",
    "\n",
    text,
    count=1
)

helper = """

function buildStrategistSystemPosture(system, officesPayload = []) {
  const ranked = (officesPayload || [])
    .map(item => {
      const state = item.state || {};
      const layer2 = item.layer2 || {};

      const ops = state.operations || {};
      const billing = state.billing || {};
      const insurance = state.insurance || {};

      const denialRate = Number(billing.denialRate || 0);
      const claimLagDays = Number(billing.claimLagDays || 0);
      const arOver30 = Number(billing.arOver30 || 0);

      const authBacklog = Number(insurance.authBacklog || 0);
      const authDelayHours = Number(insurance.authDelayHours || 0);

      const queueDepth = Number(ops.queueDepth || 0);
      const intakeBacklog = Number(ops.intakeBacklog || 0);
      const staffingCoverage = Number(ops.staffingCoverage || 0);

      const denialScore = Math.min(100, denialRate * 5.5);
      const authScore = Math.min(100, (authDelayHours * 1.4) + (authBacklog * 1.2));
      const opsScore = Math.min(100, (queueDepth * 1.5) + (intakeBacklog * 2));
      const arScore = Math.min(100, arOver30 / 2500);
      const staffingScore = Math.max(0, 100 - staffingCoverage);

      const riskScore = Math.round(
        denialScore * 0.35 +
        authScore * 0.25 +
        opsScore * 0.20 +
        arScore * 0.15 +
        staffingScore * 0.05
      );

      let status = 'stable';
      if (riskScore >= 85) status = 'critical';
      else if (riskScore >= 65) status = 'high';
      else if (riskScore >= 40) status = 'medium';

      const laneScores = {
        Billing: denialScore + arScore,
        Insurance: authScore,
        Operations: opsScore + staffingScore
      };
      const primaryDriver =
        Object.entries(laneScores).sort((a,b) => b[1] - a[1])[0]?.[0] || 'Billing';

      let summary = `${item.office}: review posture`;
      if (primaryDriver === 'Billing') {
        summary = `${item.office}: denial ${denialRate}% and AR>30 ${arOver30.toLocaleString()}`;
      } else if (primaryDriver === 'Insurance') {
        summary = `${item.office}: auth backlog ${authBacklog} and delay ${authDelayHours}h`;
      } else {
        summary = `${item.office}: queue ${queueDepth}, backlog ${intakeBacklog}, staffing ${staffingCoverage}%`;
      }

      return {
        office: item.office,
        state,
        layer2,
        riskScore,
        status,
        primaryDriver,
        summary,
        revenueAtRisk: Number(layer2.revenueAtRisk || 0),
        recoverable72h: Number(layer2.recoverable72h || 0),
        cashAcceleration14d: Number(layer2.cashAcceleration14d || 0)
      };
    })
    .sort((a,b) => b.riskScore - a.riskScore)
    .map((item, idx) => ({ ...item, riskRank: idx + 1 }));

  const top = ranked[0] || null;
  const best = [...ranked].sort((a,b) => a.riskScore - b.riskScore)[0] || null;

  const revenueAtRiskTotal = ranked.reduce((s,x) => s + (x.revenueAtRisk || 0), 0);
  const recoverable72hTotal = ranked.reduce((s,x) => s + (x.recoverable72h || 0), 0);
  const cashAcceleration14dTotal = ranked.reduce((s,x) => s + (x.cashAcceleration14d || 0), 0);

  const laneCounts = ranked.reduce((acc, x) => {
    acc[x.primaryDriver] = (acc[x.primaryDriver] || 0) + 1;
    return acc;
  }, {});
  const topSystemLane = Object.entries(laneCounts).sort((a,b) => b[1] - a[1])[0]?.[0] || 'Billing';

  return {
    ok: true,
    system,
    generatedAt: new Date().toISOString(),
    systemPosture: {
      overallRisk: top?.status || 'stable',
      revenueAtRiskTotal,
      recoverable72hTotal,
      cashAcceleration14dTotal,
      topSystemLane,
      topRiskOffice: top?.office || null,
      bestPerformingOffice: best?.office || null,
      topSystemDriver: top?.summary || null
    },
    officeRanking: ranked.map(x => ({
      office: x.office,
      riskRank: x.riskRank,
      riskScore: x.riskScore,
      status: x.status,
      primaryDriver: x.primaryDriver,
      summary: x.summary,
      revenueAtRisk: x.revenueAtRisk,
      recoverable72h: x.recoverable72h,
      cashAcceleration14d: x.cashAcceleration14d,
      recommendedAction:
        x.layer2?.bestNextActions?.[0] ||
        x.layer2?.rootCause?.[0] ||
        'Review office posture'
    })),
    deeActionBoard: {
      topPriorityNow: top ? `Intervene in ${top.office}: ${top.summary}` : 'No office selected',
      topOfficeNow: top?.office || null,
      topPayerNow: 'Medicare',
      topEscalationNow: top?.summary || null,
      teamBriefNow: top?.layer2?.bestNextActions?.[0] || 'Review highest-risk office',
      execNarrativeNow: top
        ? `${system} risk is concentrated in ${top.office}; immediate intervention is recommended.`
        : `${system} appears stable.`
    },
    variance: {
      highestRiskOffice: top?.office || null,
      bestPerformingOffice: best?.office || null,
      highestDenialOffice: ranked.find(x => x.primaryDriver === 'Billing')?.office || null,
      highestAuthDelayOffice: ranked.find(x => x.primaryDriver === 'Insurance')?.office || null,
      highestThroughputStressOffice: ranked.find(x => x.primaryDriver === 'Operations')?.office || null
    }
  };
}

"""

m = re.search(r"\napp\.(get|post|use)\(", text)
if not m:
    raise SystemExit("Could not find insertion point before routes")

idx = m.start()
text = text[:idx] + helper + "\n" + text[idx:]

p.write_text(text, encoding="utf-8")
print("force-inserted top-level buildStrategistSystemPosture")
PY

node -c server.js
grep -n "function buildStrategistSystemPosture\|buildStrategistSystemPosture(" server.js

git add server.js
git commit -m "Force top-level buildStrategistSystemPosture helper" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
