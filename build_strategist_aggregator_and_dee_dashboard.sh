#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

SERVER="server.js"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/strategist_agg
cp -f "$SERVER" "backups/strategist_agg/server.js.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

helpers = r"""
function normalizeOfficeState(state = {}) {
  const ops = state.operations || {};
  const billing = state.billing || {};
  const insurance = state.insurance || {};

  return {
    queueDepth: Number(ops.queueDepth || 0),
    intakeBacklog: Number(ops.intakeBacklog || 0),
    staffingCoverage: Number(ops.staffingCoverage || 0),

    denialRate: Number(billing.denialRate || 0),
    claimLagDays: Number(billing.claimLagDays || 0),
    arOver30: Number(billing.arOver30 || 0),

    authBacklog: Number(insurance.authBacklog || 0),
    authDelayHours: Number(insurance.authDelayHours || 0),
    pendingClaimsValue: Number(insurance.pendingClaimsValue || 0)
  };
}

function officeRiskModel(state = {}, layer2 = {}) {
  const n = normalizeOfficeState(state);

  const denialScore = Math.min(100, n.denialRate * 5.5);
  const authScore = Math.min(100, (n.authDelayHours * 1.4) + (n.authBacklog * 1.2));
  const opsScore = Math.min(100, (n.queueDepth * 1.5) + (n.intakeBacklog * 2));
  const arScore = Math.min(100, n.arOver30 / 2500);
  const staffingScore = Math.max(0, 100 - n.staffingCoverage);

  const riskScore =
    denialScore * 0.35 +
    authScore * 0.25 +
    opsScore * 0.20 +
    arScore * 0.15 +
    staffingScore * 0.05;

  const componentMap = {
    Billing: denialScore + arScore,
    Insurance: authScore,
    Operations: opsScore + staffingScore
  };

  const primaryDriver = Object.entries(componentMap).sort((a,b) => b[1] - a[1])[0]?.[0] || 'Billing';

  let status = 'stable';
  if (riskScore >= 85) status = 'critical';
  else if (riskScore >= 65) status = 'high';
  else if (riskScore >= 40) status = 'medium';

  return {
    riskScore: Math.round(riskScore),
    status,
    primaryDriver,
    metrics: n,
    layer2
  };
}

function summarizeOfficeDriver(officeName, state = {}, officeEval = {}) {
  const n = normalizeOfficeState(state);
  if (officeEval.primaryDriver === 'Billing') {
    return `${officeName}: denial ${n.denialRate}% and AR>30 ${n.arOver30.toLocaleString()}`;
  }
  if (officeEval.primaryDriver === 'Insurance') {
    return `${officeName}: auth backlog ${n.authBacklog} and delay ${n.authDelayHours}h`;
  }
  return `${officeName}: queue ${n.queueDepth}, backlog ${n.intakeBacklog}, staffing ${n.staffingCoverage}%`;
}

function buildStrategistSystemPosture(system, officesPayload = []) {
  const ranked = officesPayload
    .map(item => {
      const evald = officeRiskModel(item.state, item.layer2);
      return {
        office: item.office,
        state: item.state,
        layer2: item.layer2,
        riskScore: evald.riskScore,
        status: evald.status,
        primaryDriver: evald.primaryDriver,
        summary: summarizeOfficeDriver(item.office, item.state, evald),
        revenueAtRisk: Number(item.layer2?.revenueAtRisk || 0),
        recoverable72h: Number(item.layer2?.recoverable72h || 0),
        cashAcceleration14d: Number(item.layer2?.cashAcceleration14d || 0)
      };
    })
    .sort((a,b) => b.riskScore - a.riskScore)
    .map((item, idx) => ({
      ...item,
      riskRank: idx + 1
    }));

  const top = ranked[0] || null;
  const best = [...ranked].sort((a,b) => a.riskScore - b.riskScore)[0] || null;

  const revenueAtRiskTotal = ranked.reduce((sum, x) => sum + (x.revenueAtRisk || 0), 0);
  const recoverable72hTotal = ranked.reduce((sum, x) => sum + (x.recoverable72h || 0), 0);
  const cashAcceleration14dTotal = ranked.reduce((sum, x) => sum + (x.cashAcceleration14d || 0), 0);

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
      recommendedAction: x.layer2?.bestNextActions?.[0] || x.layer2?.output?.split('\\n').find(Boolean) || 'Review office posture'
    })),
    deeActionBoard: {
      topPriorityNow: top ? `Intervene in ${top.office}: ${top.summary}` : 'No office selected',
      topOfficeNow: top?.office || null,
      topPayerNow: 'Medicare',
      topEscalationNow: top?.summary || null,
      teamBriefNow: top?.layer2?.bestNextActions?.[0] || 'Review highest-risk office',
      execNarrativeNow: top ? `${system} risk is concentrated in ${top.office}; immediate intervention is recommended.` : `${system} appears stable.`
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

if "function buildStrategistSystemPosture(" not in text:
    # place before static section if possible
    marker = "// ── STATIC"
    if marker in text:
        text = text.replace(marker, helpers + "\n\n" + marker, 1)
    else:
        text += "\n" + helpers

routes = r"""
app.post('/api/strategist/hc/system-posture', (req, res) => {
  try {
    const {
      system = 'HonorHealth',
      offices = ['Scottsdale - Shea', 'Mesa', 'Tempe', 'North Mountain']
    } = req.body || {};

    const state = readJson(HC_NODE_STATE_FILE, {});
    const officePayloads = [];

    for (const office of offices) {
      const officeState = filterHCState(state, system, office);
      const layer2 = buildLayer2Summary(officeState, system, office);
      officePayloads.push({
        office,
        state: officeState,
        layer2
      });
    }

    const posture = buildStrategistSystemPosture(system, officePayloads);
    return res.json(posture);
  } catch (e) {
    return res.status(500).json({ ok:false, error:e.message });
  }
});

app.post('/api/honor/dee/dashboard', (req, res) => {
  try {
    const {
      system = 'HonorHealth',
      selectedOffice = 'Scottsdale - Shea',
      offices = ['Scottsdale - Shea', 'Mesa', 'Tempe', 'North Mountain'],
      audience = 'cfo',
      format = 'email'
    } = req.body || {};

    const state = readJson(HC_NODE_STATE_FILE, {});
    const selectedState = filterHCState(state, system, selectedOffice);
    const selectedLayer2 = buildLayer2Summary(selectedState, system, selectedOffice);
    const selectedBrief = buildHCBrief({
      system,
      location: selectedOffice,
      audience,
      format,
      question: 'What is driving current revenue pressure and what are we doing about it?'
    }, state);

    const officePayloads = offices.map(office => {
      const officeState = filterHCState(state, system, office);
      const layer2 = buildLayer2Summary(officeState, system, office);
      return { office, state: officeState, layer2 };
    });

    const systemPosture = buildStrategistSystemPosture(system, officePayloads);
    const alerts = buildHCAlerts({ system }, state);

    return res.json({
      ok: true,
      persona: {
        name: 'Dee Montee',
        role: 'Revenue Cycle Manager',
        system
      },
      generatedAt: new Date().toISOString(),
      selectedOffice,
      selectedOfficeData: {
        state: selectedState,
        layer2: selectedLayer2,
        brief: selectedBrief
      },
      systemPosture,
      alerts
    });
  } catch (e) {
    return res.status(500).json({ ok:false, error:e.message });
  }
});
"""

if "/api/strategist/hc/system-posture" not in text:
    # append before listen if possible
    listen_pat = re.search(r"\napp\.listen\(PORT,[\s\S]*?$", text)
    if listen_pat:
      idx = listen_pat.start()
      text = text[:idx] + "\n" + routes + "\n" + text[idx:]
    else:
      text += "\n" + routes

p.write_text(text, encoding="utf-8")
print("patched strategist aggregator + dee dashboard routes")
PY

echo "== VERIFY =="
grep -n "/api/strategist/hc/system-posture\|/api/honor/dee/dashboard\|buildStrategistSystemPosture\|officeRiskModel" "$SERVER" || true

echo "== COMMIT =="
git add "$SERVER"
git commit -m "Add strategist aggregator and Dee dashboard endpoints" || true

echo "== PUSH =="
git pull --rebase origin main || true
git push origin main || true

echo "== DEPLOY =="
fly deploy
