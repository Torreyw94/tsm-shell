const express = require('express');
const path = require('path');
const fs = require('fs');
const https = require('https');

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());

// ── DATA STORE ────────────────────────────────────────────────────────────────
const HC_DATA_DIR = path.join(__dirname, 'data', 'hc-strategist');
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
  state[req.params.nodeKey] = {
    ...(state[req.params.nodeKey] || {}),
    ...req.body,
    nodeKey: req.params.nodeKey,
    updatedAt: new Date().toISOString()
  };
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
    }).join('\\n');

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

// ── STATIC ────────────────────────────────────────────────────────────────────
app.use('/html/suite', express.static(path.join(__dirname, 'html', 'suite')));
app.use('/html/healthcare', express.static(path.join(__dirname, 'html', 'healthcare')));
app.use('/html/hc-strategist', express.static(path.join(__dirname, 'html', 'hc-strategist')));
app.use('/', express.static(path.join(__dirname, 'html')));

// catch-all LAST
app.use((req, res) => {
  res.sendFile(path.join(__dirname, 'html', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`TSM Node API running on ${PORT}`);
});
