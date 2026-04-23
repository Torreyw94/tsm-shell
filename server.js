const express = require('express');
const path = require('path');
const fs = require('fs');
const https = require('https');

const app = express();
const PORT = process.env.PORT || 8080;


// ===============================
// HC STATE FILTER (GLOBAL HELPER)
// ===============================
function filterHCState(state = {}, system = '', location = '') {
  const out = {};
  for (const [nodeKey, node] of Object.entries(state || {})) {
    if (!node || typeof node !== 'object') continue;

    const nodeSystem = String(node.system || '').trim();
    const nodeLocation = String(node.location || '').trim();

    const systemOk = !system || nodeSystem === system;
    const locationOk = !location || nodeLocation === location;

    if (systemOk && locationOk) {
      out[nodeKey] = node;
    }
  }
  return out;
}



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



function buildHCBrief({ system = '', location = '', question = '' }) {
  return {
    subject: `${location} Revenue Pressure Update`,
    body: `System: ${system}

Location: ${location}

Summary:
Revenue pressure is being driven by billing, insurance, and operational constraints.

Key Focus:
- Reduce denial backlog
- Accelerate auth processing
- Stabilize intake throughput

Executive Direction:
Immediate intervention recommended in high-risk lanes.

Question Context:
${question}
`
  };
}



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



app.use(express.json());

// ── HUB ROUTE ──
app.get("/hub", (req, res) => res.sendFile(path.join(__dirname, "html", "hub", "index.html")));

app.use(express.static(__dirname, {
  extensions: ['html']
}));

// ── DATA STORE ────────────────────────────────────────────────────────────────
const HC_DATA_ROOT = process.env.TSM_DATA_ROOT || '/data';
const HC_DATA_DIR = path.join(HC_DATA_ROOT, 'hc-strategist');
const HC_REPORTS_FILE = path.join(HC_DATA_DIR, 'reports.json');
const HC_NODE_STATE_FILE = path.join(HC_DATA_DIR, 'node-state.json');
const HC_PROFILES_FILE = path.join(HC_DATA_DIR, 'profiles.json');

function ensureStore() {
  fs.mkdirSync(HC_DATA_DIR, { recursive: true });
  if (!fs.existsSync(HC_REPORTS_FILE)) fs.writeFileSync(HC_REPORTS_FILE, '[]', 'utf8');
  if (!fs.existsSync(HC_NODE_STATE_FILE)) fs.writeFileSync(HC_NODE_STATE_FILE, '{}', 'utf8');
  if (!fs.existsSync(HC_PROFILES_FILE)) {
    fs.writeFileSync(HC_PROFILES_FILE, JSON.stringify([
      { id: "honor", name: "HonorHealth", system: "HonorHealth", locations: ["All", "Scottsdale - Shea", "Osborn"] },
      { id: "banner", name: "Banner", system: "Banner", locations: ["All"] },
      { id: "dignity", name: "Dignity", system: "Dignity", locations: ["All"] }
    ], null, 2), 'utf8');
  }
}
ensureStore();

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function writeJson(file, value) {
  fs.writeFileSync(file, JSON.stringify(value, null, 2), 'utf8');
}

// ── CORE STATUS ───────────────────────────────────────────────────────────────
app.get('/api/status', (req, res) => {
  res.json({
    status: "SOVEREIGN ONLINE",
    valuation: "$600,000",
    bridge: "CONNECTED"
  });
});

// ── HC REPORTS ────────────────────────────────────────────────────────────────
app.get('/api/hc/reports', (req, res) => {
  const reports = readJson(HC_REPORTS_FILE, []);
  res.json({ ok: true, count: reports.length, reports });
});

app.post('/api/hc/reports', (req, res) => {
  const reports = readJson(HC_REPORTS_FILE, []);
  const now = new Date().toISOString();
  const report = {
    id: `rpt_${Date.now()}`,
    title: req.body.title || 'Untitled Report',
    company: req.body.company || 'General Healthcare',
    query: req.body.query || '',
    summary: req.body.summary || '',
    nodeResults: req.body.nodeResults || {},
    createdAt: now,
    updatedAt: now
  };
  reports.unshift(report);
  writeJson(HC_REPORTS_FILE, reports.slice(0, 300));
  res.json({ ok: true, report });
});

app.delete('/api/hc/reports/:id', (req, res) => {
  const reports = readJson(HC_REPORTS_FILE, []);
  const next = reports.filter(r => r.id !== req.params.id);
  writeJson(HC_REPORTS_FILE, next);
  res.json({ ok: true });
});

// ── HC NODE STATE ─────────────────────────────────────────────────────────────
app.get('/api/hc/nodes', (req, res) => {
  const state = readJson(HC_NODE_STATE_FILE, {});
  res.json({ ok: true, state, generatedAt: new Date().toISOString() });
});

app.post('/api/hc/nodes/:nodeKey', (req, res) => {
  const state = readJson(HC_NODE_STATE_FILE, {});
  const merged = {
    ...(state[req.params.nodeKey] || {}),
    ...req.body,
    nodeKey: req.params.nodeKey,
    updatedAt: new Date().toISOString()
  };

  // Generate live BNCA from actual node telemetry
  const n = merged;
  merged.bnca = `TOP ISSUE
${n.findings || 'Cross-lane operational drag is the primary issue.'}

WHY IT MATTERS
Live telemetry received for ${n.system || 'this system'} · ${n.location || 'all locations'}.

METRICS
Queue Depth: ${n.queueDepth ?? 'N/A'} · Intake Backlog: ${n.intakeBacklog ?? 'N/A'} · Staffing: ${n.staffingCoverage ?? 'N/A'}%
Denial Rate: ${n.denialRate ?? 'N/A'}% · Claim Lag: ${n.claimLagDays ?? 'N/A'} days · AR >30: ${n.arOver30 ?? 'N/A'}
Auth Backlog: ${n.authBacklog ?? 'N/A'} · Auth Delay: ${n.authDelayHours ?? 'N/A'}h · Pending Claims: ${n.pendingClaimsValue ?? 'N/A'}

BEST NEXT COURSE OF ACTION
1. Clear highest-value backlog first
2. Escalate auth and documentation blockers older than 24-72 hours
3. Align intake, billing, and scheduling handoffs for the next shift

OWNER LANES
Operations · Billing · Insurance

CONFIDENCE
92%`;

  state[req.params.nodeKey] = merged;
  writeJson(HC_NODE_STATE_FILE, state);
  res.json({ ok: true, node: state[req.params.nodeKey] });
});

// ── HC ENTERPRISE PROFILES / FILTER / BNCA / ASK ─────────────────────────────
app.get('/api/hc/profiles', (req, res) => {
  res.json({ ok: true, profiles: readJson(HC_PROFILES_FILE, []) });
});

app.get('/api/hc/nodes/filter', (req, res) => {
  const { system = '', location = '' } = req.query;
  const state = readJson(HC_NODE_STATE_FILE, {});
  const filtered = Object.fromEntries(
    Object.entries(state).filter(([_, v]) => {
      return (!system || v.system === system) &&
             (!location || location === 'All' || v.location === location);
    })
  );
  res.json({ ok: true, state: filtered });
});

app.post('/api/hc/bnca', (req, res) => {
  const { system = '', location = '' } = req.body || {};
  const state = readJson(HC_NODE_STATE_FILE, {});

  const nodes = Object.values(state).filter(v =>
    (!system || v.system === system) &&
    (!location || location === 'All' || v.location === location)
  );

  const top = nodes.find(v => v.findings)?.findings || 'Operational drag across nodes';

  res.json({
    ok: true,
    bnca: {
      system,
      location,
      topIssue: top,
      whyItMatters: 'Revenue + throughput pressure',
      bestNextCourseOfAction: [
        'Clear high-value backlog',
        'Escalate auth delays',
        'Rebalance intake + billing'
      ],
      ownerLanes: ['Operations', 'Billing', 'Insurance'],
      confidence: '88%'
    }
  });
});


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

  return {
    enriched,
    revenueAtRisk: Math.round(revenueAtRisk),
    recoverable72h,
    recoverable30d,
    top: enriched.slice(0, 3)
  };
}





function buildOfficeContext(filtered = {}) {
  const ops = filtered.operations || {};
  const billing = filtered.billing || {};
  const insurance = filtered.insurance || {};
  const compliance = filtered.compliance || {};

  return {
    officeName: ops.officeName || billing.officeName || insurance.officeName || compliance.officeName || '',
    officeManager: ops.officeManager || billing.officeManager || insurance.officeManager || compliance.officeManager || '',
    persistentIssues: [
      ops.findings || null,
      billing.findings || null,
      insurance.findings || null,
      compliance.findings || null
    ].filter(Boolean),
    localConstraints: [
      ops.localConstraints || null,
      billing.localConstraints || null,
      insurance.localConstraints || null,
      compliance.localConstraints || null
    ].filter(Boolean),
    recentWins: [
      ops.recentWins || null,
      billing.recentWins || null,
      insurance.recentWins || null,
      compliance.recentWins || null
    ].filter(Boolean)
  };
}

function buildAudienceBrief({ system, location, audience='om', format='brief', question='', filtered={}, result={} }) {
  const office = buildOfficeContext(filtered);
  const top = result.top || [];
  const topLane = result.highestYieldLane || (top[0]?.nodeKey ? top[0].nodeKey.charAt(0).toUpperCase() + top[0].nodeKey.slice(1) : 'Unassigned');
  const rev = Number(result.revenueAtRisk || 0);
  const rec72 = Number(result.recoverable72h || 0);
  const rec30 = Number(result.recoverable30d || 0);
  const cash14 = Number(result.cashAcceleration14d || 0);

  const ops = filtered.operations || {};
  const billing = filtered.billing || {};
  const insurance = filtered.insurance || {};
  const compliance = filtered.compliance || {};

  const rootCause = [
    billing.denialRate != null || billing.claimLagDays != null
      ? `Billing is showing denial pressure at ${billing.denialRate ?? 'N/A'}% with claim lag at ${billing.claimLagDays ?? 'N/A'} days.`
      : null,
    insurance.authBacklog != null || insurance.authDelayHours != null
      ? `Insurance is carrying ${insurance.authBacklog ?? 'N/A'} pending auth items with an average delay of ${insurance.authDelayHours ?? 'N/A'} hours.`
      : null,
    ops.queueDepth != null || ops.intakeBacklog != null || ops.staffingCoverage != null
      ? `Operations is reporting queue depth ${ops.queueDepth ?? 'N/A'}, intake backlog ${ops.intakeBacklog ?? 'N/A'}, and staffing coverage ${ops.staffingCoverage ?? 'N/A'}%.`
      : null,
    compliance.openFindings != null || compliance.auditExposure != null
      ? `Compliance is carrying ${compliance.openFindings ?? 'N/A'} open findings with audit exposure of $${compliance.auditExposure ?? 'N/A'}.`
      : null
  ].filter(Boolean).join(' ');

  const actions = [
    'Clear the highest-value backlog first.',
    'Escalate aged auth and documentation blockers older than 24–72 hours.',
    'Align intake, billing, and scheduling handoffs for the next shift.'
  ];

  const summaryLine = `Current cross-lane pressure is concentrated in ${top.map(t => t.nodeKey).join(', ') || 'the active operating lanes'}, with $${rev.toLocaleString()} at risk and $${cash14.toLocaleString()} in projected 14-day cash acceleration opportunity.`;
  const officeLine = office.officeName ? `Office: ${office.officeName}` : '';
  const managerLine = office.officeManager ? `Office manager: ${office.officeManager}` : '';

  const audiencePrefix = {
    om: 'Operational summary for office management:',
    director: 'Cross-functional leadership summary:',
    cfo: 'Financial impact summary:',
    ceo: 'Executive summary:'
  }[audience] || 'Leadership summary:';

  if (format === 'status_update') {
    return `${audiencePrefix}

System: ${system || 'General Healthcare'}
Location: ${location || 'All'}${officeLine ? '\n' + officeLine : ''}${managerLine ? '\n' + managerLine : ''}

Top issue: ${top.map(t => t.nodeKey).join(' + ') || 'No qualifying node pressure found'}
Highest-yield lane: ${topLane}
Revenue at risk: $${rev.toLocaleString()}
Recoverable in 72 hours: $${rec72.toLocaleString()}
Projected 14-day cash acceleration: $${cash14.toLocaleString()}

Root cause:
${rootCause || 'No live telemetry available.'}${office.persistentIssues.length ? '\n\nPersistent issues:\n- ' + office.persistentIssues.join('\n- ') : ''}${office.localConstraints.length ? '\n\nLocal constraints:\n- ' + office.localConstraints.join('\n- ') : ''}${office.recentWins.length ? '\n\nRecent wins:\n- ' + office.recentWins.join('\n- ') : ''}

Immediate actions:
1. ${actions[0]}
2. ${actions[1]}
3. ${actions[2]}`;
  }

  if (format === 'talking_points') {
    return `TALKING POINTS

• ${summaryLine}
• Highest-yield lane right now is ${topLane}.
• Recoverable value is $${rec72.toLocaleString()} in 72 hours and $${rec30.toLocaleString()} in 30 days.
• Root cause is cross-functional: ${rootCause || 'no live telemetry available.'}
• Immediate response is to ${actions[0].toLowerCase()} ${actions[1].toLowerCase()} ${actions[2].toLowerCase()}`;
  }

  if (format === 'email') {
    return `Subject: ${location || 'Site'} Revenue Pressure Update

Team,

This is a current update for ${system || 'General Healthcare'}${location ? ' — ' + location : ''}.

${summaryLine}

Highest-yield lane at this time is ${topLane}. Estimated recoverable value is $${rec72.toLocaleString()} in the next 72 hours and $${rec30.toLocaleString()} over 30 days.

Root cause:
${rootCause || 'No live telemetry available.'}${office.persistentIssues.length ? '\n\nPersistent issues:\n- ' + office.persistentIssues.join('\n- ') : ''}${office.localConstraints.length ? '\n\nLocal constraints:\n- ' + office.localConstraints.join('\n- ') : ''}${office.recentWins.length ? '\n\nRecent wins:\n- ' + office.recentWins.join('\n- ') : ''}

Current response plan:
1. ${actions[0]}
2. ${actions[1]}
3. ${actions[2]}

Please let me know if you would like this converted into a more detailed operating brief.

Thanks,`;
  }

  return `${audiencePrefix}

${summaryLine}

Highest-yield lane: ${topLane}
Revenue at risk: $${rev.toLocaleString()}
Recoverable value:
- 72 hours: $${rec72.toLocaleString()}
- 30 days: $${rec30.toLocaleString()}

Root cause:
${rootCause || 'No live telemetry available.'}${office.persistentIssues.length ? '\n\nPersistent issues:\n- ' + office.persistentIssues.join('\n- ') : ''}${office.localConstraints.length ? '\n\nLocal constraints:\n- ' + office.localConstraints.join('\n- ') : ''}${office.recentWins.length ? '\n\nRecent wins:\n- ' + office.recentWins.join('\n- ') : ''}

Recommended next actions:
1. ${actions[0]}
2. ${actions[1]}
3. ${actions[2]}

Question context:
${question || 'No additional question provided.'}`;
}


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

    const highestYieldLane = top[0]?.nodeKey
      ? top[0].nodeKey.charAt(0).toUpperCase() + top[0].nodeKey.slice(1)
      : 'Unassigned';

    const cashAcceleration14d = Math.round(result.recoverable30d * 0.7);

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

PROJECTED CASH ACCELERATION
14 DAYS: $${cashAcceleration14d.toLocaleString()}

HIGHEST-YIELD LANE
${highestYieldLane}

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
      cashAcceleration14d,
      highestYieldLane,
      top: result.top
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});




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


app.post('/api/hc/brief', (req, res) => {
  try {
    const {
      system = '',
      location = '',
      audience = 'om',
      format = 'brief',
      question = ''
    } = req.body || {};

    const state = readJson(HC_NODE_STATE_FILE, {});
    const filtered = Object.fromEntries(
      Object.entries(state).filter(([_, n]) =>
        (!system || (n.system || '') === system) &&
        (!location || location === 'All' || (n.location || '') === location)
      )
    );

    const result = aggregateLayer2(filtered);

    const highestYieldLane =
      result.top?.[0]?.nodeKey
        ? result.top[0].nodeKey.charAt(0).toUpperCase() + result.top[0].nodeKey.slice(1)
        : 'Unassigned';

    result.highestYieldLane = highestYieldLane;
    result.cashAcceleration14d = result.cashAcceleration14d || Math.round((result.recoverable30d || 0) * 0.7);

    const brief = buildAudienceBrief({
      system,
      location,
      audience,
      format,
      question,
      filtered,
      result
    });

    res.json({
      ok: true,
      brief,
      audience,
      format,
      system,
      location,
      revenueAtRisk: result.revenueAtRisk || 0,
      recoverable72h: result.recoverable72h || 0,
      recoverable30d: result.recoverable30d || 0,
      cashAcceleration14d: result.cashAcceleration14d || 0,
      highestYieldLane
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});


async function callGroq(systemPrompt, userMessage) {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) return null;
  try {
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {'Content-Type':'application/json','Authorization':`Bearer ${apiKey}`},
      body: JSON.stringify({
        model: 'llama-3.1-8b-instant',
        max_tokens: 400,
        messages: [
          {role:'system', content: systemPrompt},
          {role:'user', content: userMessage}
        ]
      })
    });
    const d = await res.json();
    return d.choices?.[0]?.message?.content || null;
  } catch(e) {
    console.error('Groq error:', e.message);
    return null;
  }
}

app.post('/api/hc/ask', async (req,res)=>{
  try{
    const {query='',system='',location='',nodeKey=''} = req.body||{};
    const state = readJson(HC_NODE_STATE_FILE,{});
    // Groq persona analysis for specific node
    if(nodeKey && state[nodeKey]) {
      const n = state[nodeKey];
      const sp = `You are the ${nodeKey.toUpperCase()} specialist for HonorHealth Scottsdale - Shea. Use the actual metrics. Be specific and actionable. Max 8 lines.`;
      const um = `QUERY: ${query||'Provide BNCA analysis'}\nDATA: ${JSON.stringify({findings:n.findings,...n})}`;
      const gr = await callGroq(sp, um);
      return res.json({ok:true, content: gr || n.bnca || n.findings || 'No data'});
    }

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



function filterHCState(state = {}, system = '', location = '') {
  const out = {};
  for (const [nodeKey, node] of Object.entries(state || {})) {
    if (!node || typeof node !== 'object') continue;

    const nodeSystem = String(node.system || '').trim();
    const nodeLocation = String(node.location || '').trim();

    const systemOk = !system || nodeSystem === system;
    const locationOk = !location || nodeLocation === location;

    if (systemOk && locationOk) {
      out[nodeKey] = node;
    }
  }
  return out;
}

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



// ── STATIC ────────────────────────────────────────────────────────────────────
app.use('/html/suite', express.static(path.join(__dirname, 'html', 'suite')));
app.use('/html/healthcare', express.static(path.join(__dirname, 'html', 'healthcare')));
app.use('/html/hc-strategist', express.static(path.join(__dirname, 'html', 'hc-strategist')));
app.use('/html/main-strategist', express.static(path.join(__dirname, 'html', 'main-strategist')));
app.use('/', express.static(path.join(__dirname, 'html')));

// catch-all LAST

});


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



app.post('/api/strategist/hc/dee-action', (req, res) => {
  try {
    const {
      system = 'HonorHealth',
      selectedOffice = 'Scottsdale - Shea',
      offices = ['Scottsdale - Shea', 'Mesa', 'Tempe', 'North Mountain'],
      prompt = ''
    } = req.body || {};

    const state = readJson(HC_NODE_STATE_FILE, {});
    const selectedState = filterHCState(state, system, selectedOffice);
    const layer2 = buildLayer2Summary(selectedState, system, selectedOffice);

    const officePayloads = offices.map(office => {
      const officeState = filterHCState(state, system, office);
      const officeLayer2 = buildLayer2Summary(officeState, system, office);
      return { office, state: officeState, layer2: officeLayer2 };
    });

    const posture = buildStrategistSystemPosture(system, officePayloads);

    const alerts = [];
    Object.entries(state || {}).forEach(([nodeKey, n]) => {
      if (!n || typeof n !== 'object') return;
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
    });

    const top = posture?.officeRanking?.[0] || {};
    const selectedOps = selectedState.operations || {};
    const selectedBilling = selectedState.billing || {};
    const selectedInsurance = selectedState.insurance || {};

    const liveSignals = [
      {
        title: 'Top Priority',
        urgency: top.status || 'high',
        source: top.office || selectedOffice,
        detail: top.summary || `Intervene in ${selectedOffice}`
      },
      {
        title: 'Payer Friction',
        urgency: Number(selectedInsurance.authDelayHours || 0) > 48 ? 'urgent' : 'med',
        source: selectedOffice,
        detail: `Auth backlog ${selectedInsurance.authBacklog || 0} · delay ${selectedInsurance.authDelayHours || 0}h`
      },
      {
        title: 'Denial Pressure',
        urgency: Number(selectedBilling.denialRate || 0) > 10 ? 'urgent' : 'med',
        source: selectedOffice,
        detail: `Denial ${selectedBilling.denialRate || 0}% · lag ${selectedBilling.claimLagDays || 0}d`
      },
      {
        title: 'Throughput',
        urgency: Number(selectedOps.queueDepth || 0) > 25 ? 'high' : 'med',
        source: selectedOffice,
        detail: `Queue ${selectedOps.queueDepth || 0} · backlog ${selectedOps.intakeBacklog || 0} · staffing ${selectedOps.staffingCoverage || 0}%`
      }
    ];

    const actionBoard = {
      source: 'TSM Strategist',
      selectedOffice,
      posture: posture.systemPosture || {},
      topPriorityNow: top.summary || `Intervene in ${selectedOffice}`,
      officeToEscalate: top.office || selectedOffice,
      payerFocus: Number(selectedInsurance.authDelayHours || 0) > 48 ? 'Prior Authorization' : 'Medicare',
      liveSignals,
      actions: [
        `Run denial recovery plan for ${selectedOffice}`,
        `Escalate payer auth blockers for ${selectedOffice}`,
        `Compare ${selectedOffice} vs best-performing office`
      ],
      strategistNarrative:
        `${system} risk is concentrated in ${top.office || selectedOffice}. ` +
        `Highest-yield lane is ${layer2.highestYieldLane || 'Billing'}. ` +
        `Immediate focus: ${layer2.bestNextActions?.[0] || 'Clear highest-value backlog first'}`,
      alertCount: alerts.length
    };

    // Prompt-based action branching
    const promptLower = (prompt || '').toLowerCase();
    let actionView = 'default';
    if (promptLower.includes('denial recovery')) actionView = 'denial';
    else if (promptLower.includes('auth blocker') || promptLower.includes('payer')) actionView = 'auth';
    else if (promptLower.includes('compare') || promptLower.includes('best-performing')) actionView = 'compare';

    let actionDetail = null;
    if (actionView === 'denial') {
      actionDetail = {
        view: 'denial',
        title: 'Denial Recovery Plan',
        steps: [
          `1. Pull all denied claims for ${selectedOffice} from last 30 days`,
          `2. Sort by denial reason — current top: ${selectedBilling.denialRate || 0}% rate`,
          `3. Resubmit clean claims within 72h — ${layer2.recoverable72h ? '$'+Number(layer2.recoverable72h).toLocaleString()+' recoverable' : 'calculate recoverable'}`,
          `4. Escalate payer-specific denials to billing lead`,
          `5. Flag claim lag (${selectedBilling.claimLagDays || 0}d) for process review`,
        ],
        metric: { label: 'Denial Rate', value: selectedBilling.denialRate + '%', target: '<5%' }
      };
    } else if (actionView === 'auth') {
      actionDetail = {
        view: 'auth',
        title: 'Payer Auth Escalation',
        steps: [
          `1. Pull all pending auth requests for ${selectedOffice} older than 24h`,
          `2. Auth backlog: ${selectedInsurance.authBacklog || 0} cases · delay: ${selectedInsurance.authDelayHours || 0}h`,
          `3. Call top 3 payers directly — prioritize Medicare/Prior Auth cases`,
          `4. Submit peer-to-peer review requests for denials over $5,000`,
          `5. Escalate unresolved auths >72h to medical director`,
        ],
        metric: { label: 'Auth Delay', value: selectedInsurance.authDelayHours + 'h', target: '<24h' }
      };
    } else if (actionView === 'compare') {
      const best = officePayloads.find(o => o.office === posture?.systemPosture?.bestPerformingOffice) || officePayloads[1];
      actionDetail = {
        view: 'compare',
        title: `${selectedOffice} vs ${best?.office || 'Best Office'}`,
        comparison: [
          { label: 'Denial Rate', selected: selectedBilling.denialRate + '%', best: (best?.layer2?.denialRate || 0) + '%' },
          { label: 'Auth Delay', selected: selectedInsurance.authDelayHours + 'h', best: (best?.layer2?.authDelayHours || 0) + 'h' },
          { label: 'Queue Depth', selected: selectedOps.queueDepth, best: best?.layer2?.queueDepth || 0 },
          { label: 'Revenue at Risk', selected: '$'+Number(layer2.revenueAtRisk||0).toLocaleString(), best: '$'+Number(best?.layer2?.revenueAtRisk||0).toLocaleString() },
          { label: 'Recoverable 72h', selected: '$'+Number(layer2.recoverable72h||0).toLocaleString(), best: '$'+Number(best?.layer2?.recoverable72h||0).toLocaleString() },
        ]
      };
    }

    return res.json({
      ok: true,
      source: 'TSM Strategist',
      generatedAt: new Date().toISOString(),
      selectedOffice,
      prompt,
      actionView,
      actionDetail,
      layer2,
      posture,
      alerts,
      actionBoard
    });
  } catch (e) {
    return res.status(500).json({ ok:false, error:e.message });
  }
});


app.listen(PORT, '0.0.0.0', () => {
  console.log(`TSM Node API running on ${PORT}`);
});



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


// ===== FRONTEND FALLBACK (KEEP LAST) =====
app.use((req, res) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ ok: false, error: 'API route not found' });
  }

  // serve exact frontend file/path when present, otherwise launcher
  return res.sendFile(path.join(__dirname, req.path), (err) => {
    if (err) {
      return res.sendFile(path.join(__dirname, 'html', 'index.html'));
    }
  });
});




/* ===== BNCA EXECUTION LOOP ===== */
global.HC_TASK_QUEUE = global.HC_TASK_QUEUE || [];

function buildBncaForOffice(office) {
  const officeName = office || "Scottsdale - Shea";

  const officeMap = {
    "Scottsdale - Shea": {
      riskScore: 92,
      denialRate: 12.4,
      authDelay: 56,
      queueDepth: 31,
      revenueAtRisk: 229850,
      recoverable72h: 78149,
      cashAcceleration14d: 109409,
      highestYieldLane: "Insurance",
      rootCause: [
        "Billing: denial 12.4% with lag 6d",
        "Insurance: auth backlog 27, delay 56h",
        "Operations: queue 31, backlog 18, staffing 86%"
      ],
      bestNextActions: [
        "Clear the highest-value backlog first",
        "Escalate auth and documentation blockers older than 24–72 hours",
        "Align intake, billing, and scheduling handoffs for the next shift"
      ],
      ownerLanes: ["Operations", "Billing", "Insurance"],
      summary: "HonorHealth risk is concentrated in Scottsdale - Shea. Highest-yield lane is Insurance. Immediate focus: Clear the highest-value backlog first.",
      recommendedAction: "Execute BNCA and assign recovery ownership"
    },
    "Mesa Family Practice": {
      riskScore: 84,
      denialRate: 9.8,
      authDelay: 22,
      queueDepth: 18,
      revenueAtRisk: 182000,
      recoverable72h: 62000,
      cashAcceleration14d: 98000,
      highestYieldLane: "Operations",
      rootCause: [
        "Operations: queue pressure and staffing gaps",
        "Billing: follow-up lag on aging claims",
        "Insurance: moderate auth friction"
      ],
      bestNextActions: [
        "Stabilize staffing and reduce queue pressure",
        "Push aged claims through billing follow-up",
        "Triage auth blockers by payer priority"
      ],
      ownerLanes: ["Operations", "Billing"],
      summary: "Mesa pressure is operational first, then billing throughput. Immediate focus: stabilize staffing and reduce queue pressure.",
      recommendedAction: "Stabilize OM operations and re-run BNCA"
    }
  };

  const d = officeMap[officeName] || officeMap["Scottsdale - Shea"];
  const bestOffice = officeName === "Scottsdale - Shea" ? "Mesa Family Practice" : "Scottsdale - Shea";

  return {
    ok: True,
    selectedOffice: officeName,
    actionView: "default",
    actionDetail: None,
    layer2: {
      ok: True,
      system: "HonorHealth",
      location: officeName,
      revenueAtRisk: d["revenueAtRisk"],
      recoverable72h: d["recoverable72h"],
      recoverable30d: int(d["recoverable72h"] * 2),
      cashAcceleration14d: d["cashAcceleration14d"],
      highestYieldLane: d["highestYieldLane"],
      rootCause: d["rootCause"],
      bestNextActions: d["bestNextActions"],
      ownerLanes: d["ownerLanes"],
      confidence: 91,
      summary: d["summary"]
    },
    actionBoard: {
      topPriorityNow: f"{officeName}: denial {d['denialRate']}% and AR>30 {d['revenueAtRisk']:,}",
      payerFocus: "Prior Authorization",
      strategistNarrative: d["summary"],
      actions: d["bestNextActions"],
      liveSignals: [
        {"title": "Denial Pressure", "urgency": "urgent", "detail": f"Denial {d['denialRate']}% with lag"},
        {"title": "Throughput", "urgency": "high", "detail": f"Queue {d['queueDepth']} · staffing pressure"},
        {"title": "Auth Friction", "urgency": "high", "detail": f"Delay {d['authDelay']}h"}
      ]
    },
    posture: {
      systemPosture: {
        overallRisk: "high",
        topRiskOffice: officeName,
        bestPerformingOffice: bestOffice,
        topSystemLane: d["highestYieldLane"],
        topSystemDriver: d["summary"],
        recoverable72hTotal: d["recoverable72h"] + 62000
      },
      officeRanking: [
        {
          "office": "Scottsdale - Shea",
          "riskRank": 1,
          "riskScore": 92,
          "status": "high",
          "summary": "Denial 12.4%, auth backlog 56h",
          "primaryDriver": "Denial + Auth",
          "recommendedAction": "Clear highest-value backlog first",
          "revenueAtRisk": 229850,
          "recoverable72h": 78149,
          "cashAcceleration14d": 109409
        },
        {
          "office": "Mesa Family Practice",
          "riskRank": 2,
          "riskScore": 84,
          "status": "medium",
          "summary": "Queue + staffing pressure",
          "primaryDriver": "Operations",
          "recommendedAction": "Stabilize staffing and reduce queue pressure",
          "revenueAtRisk": 182000,
          "recoverable72h": 62000,
          "cashAcceleration14d": 98000
        }
      ]
    },
    alerts: [
      {"type": "QUEUE_PRESSURE", "severity": "MEDIUM", "nodeKey": "operations", "message": f"{officeName}: queue depth {d['queueDepth']}"},
      {"type": "DENIAL_SPIKE", "severity": "HIGH", "nodeKey": "billing", "message": f"{officeName}: denial rate {d['denialRate']}%"},
      {"type": "AUTH_DELAY", "severity": "HIGH", "nodeKey": "insurance", "message": f"{officeName}: auth delay {d['authDelay']}h"}
    ]
  }

app.post('/api/hc/delegate', (req, res) => {
  const office = req.body?.office || 'Scottsdale - Shea';
  const action = req.body?.action || 'Execute BNCA';
  const ownerLane = req.body?.ownerLane || 'Billing/Insurance';
  const mode = req.body?.mode || 'bnca';

  const task = {
    id: Date.now(),
    office,
    action,
    ownerLane,
    mode,
    status: 'assigned',
    createdAt: new Date().toISOString()
  };

  global.HC_TASK_QUEUE.unshift(task);
  global.HC_TASK_QUEUE = global.HC_TASK_QUEUE.slice(0, 25);

  return res.json({ ok: true, task, queue: global.HC_TASK_QUEUE });
});

app.get('/api/hc/tasks', (_req, res) => {
  return res.json({ ok: true, tasks: global.HC_TASK_QUEUE || [] });
});

app.post('/api/hc/bnca', (req, res) => {
  const office = req.body?.office || 'Scottsdale - Shea';
  const mode = req.body?.mode || 'bnca';
  const data = buildBncaForOffice(office);

  if (mode === 'payer') {
    data["actionView"] = "auth";
    data["actionDetail"] = {
      "view": "auth",
      "title": "Payer Auth Escalation",
      "steps": [
        f"Pull all pending auth requests for {office} older than 24h",
        "Auth backlog: 27 cases · delay: 56h",
        "Call top 3 payers directly — prioritize Medicare/Prior Auth cases",
        "Submit peer-to-peer review requests for denials over $5,000",
        "Escalate unresolved auths >72h to medical director"
      ],
      "metric": {"label": "Auth Delay", "value": "56h", "target": "<24h"}
    };
  } else if (mode === 'brief') {
    data["actionView"] = "brief";
  } else if (mode === 'recovery') {
    data["actionView"] = "recovery";
  }

  return res.json(data);
});
/* ===== END BNCA EXECUTION LOOP ===== */

