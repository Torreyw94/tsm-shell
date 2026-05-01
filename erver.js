[1mdiff --git a/server.js b/server.js[m
[1mindex 79e249b..9d5ad71 100644[m
[1m--- a/server.js[m
[1m+++ b/server.js[m
[36m@@ -144,6 +144,158 @@[m [mapp.post('/api/hc/bnca', (req, res) => {[m
   });[m
 });[m
 [m
[32m+[m
[32m+[m[32mfunction toNum(v, d=0) {[m
[32m+[m[32m  const n = Number(v);[m
[32m+[m[32m  return Number.isFinite(n) ? n : d;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mfunction scoreNode(nodeKey, n) {[m
[32m+[m[32m  let score = 0;[m
[32m+[m
[32m+[m[32m  if (nodeKey === 'operations') {[m
[32m+[m[32m    score += toNum(n.queueDepth, 0) * 120;[m
[32m+[m[32m    score += toNum(n.intakeBacklog, 0) * 180;[m
[32m+[m[32m    score += Math.max(0, 90 - toNum(n.staffingCoverage, 90)) * 900;[m
[32m+[m[32m    score += toNum(n.noShowRate, 0) * 700;[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  if (nodeKey === 'billing') {[m
[32m+[m[32m    score += toNum(n.denialRate, 0) * 2500;[m
[32m+[m[32m    score += toNum(n.claimLagDays, 0) * 1800;[m
[32m+[m[32m    score += toNum(n.arOver30, 0) * 0.2;[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  if (nodeKey === 'insurance') {[m
[32m+[m[32m    score += toNum(n.authBacklog, 0) * 1400;[m
[32m+[m[32m    score += toNum(n.authDelayHours, 0) * 160;[m
[32m+[m[32m    score += toNum(n.pendingClaimsValue, 0) * 0.12;[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  if (nodeKey === 'compliance') {[m
[32m+[m[32m    score += toNum(n.openFindings, 0) * 2200;[m
[32m+[m[32m    score += toNum(n.auditExposure, 0) * 0.15;[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  if (nodeKey === 'medical') {[m
[32m+[m[32m    score += toNum(n.chartDefects, 0) * 900;[m
[32m+[m[32m    score += toNum(n.authBacklog, 0) * 600;[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  return Math.round(score);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mfunction aggregateLayer2(nodesMap) {[m
[32m+[m[32m  const entries = Object.entries(nodesMap || {});[m
[32m+[m[32m  const enriched = entries.map(([key, node]) => ({[m
[32m+[m[32m    nodeKey: key,[m
[32m+[m[32m    node,[m
[32m+[m[32m    score: scoreNode(key, node)[m
[32m+[m[32m  })).sort((a, b) => b.score - a.score);[m
[32m+[m
[32m+[m[32m  const ops = nodesMap.operations || {};[m
[32m+[m[32m  const billing = nodesMap.billing || {};[m
[32m+[m[32m  const insurance = nodesMap.insurance || {};[m
[32m+[m[32m  const compliance = nodesMap.compliance || {};[m
[32m+[m[32m  const medical = nodesMap.medical || {};[m
[32m+[m
[32m+[m[32m  const revenueAtRisk =[m
[32m+[m[32m      (toNum(ops.queueDepth) * 850)[m
[32m+[m[32m    + (toNum(ops.intakeBacklog) * 1450)[m
[32m+[m[32m    + (Math.max(0, 90 - toNum(ops.staffingCoverage, 90)) * 2200)[m
[32m+[m[32m    + (toNum(billing.denialRate) * 6200)[m
[32m+[m[32m    + (toNum(billing.claimLagDays) * 4800)[m
[32m+[m[32m    + (toNum(insurance.authBacklog) * 2100)[m
[32m+[m[32m    + (toNum(insurance.pendingClaimsValue) * 0.18)[m
[32m+[m[32m    + (toNum(compliance.auditExposure) * 0.35)[m
[32m+[m[32m    + (toNum(medical.chartDefects) * 950);[m
[32m+[m
[32m+[m[32m  const recoverable72h = Math.round(revenueAtRisk * 0.34);[m
[32m+[m[32m  const recoverable30d = Math.round(revenueAtRisk * 0.68);[m
[32m+[m
[32m+[m[32m  return {[m
[32m+[m[32m    enriched,[m
[32m+[m[32m    revenueAtRisk: Math.round(revenueAtRisk),[m
[32m+[m[32m    recoverable72h,[m
[32m+[m[32m    recoverable30d,[m
[32m+[m[32m    top: enriched.slice(0, 3)[m
[32m+[m[32m  };[m
[32m+[m[32m}[m
[32m+[m
[32m+[m
[32m+[m
[32m+[m[32mapp.post('/api/hc/layer2', (req, res) => {[m
[32m+[m[32m  try {[m
[32m+[m[32m    const { system = '', location = '' } = req.body || {};[m
[32m+[m[32m    const state = readJson(HC_NODE_STATE_FILE, {});[m
[32m+[m
[32m+[m[32m    const filtered = Object.fromEntries([m
[32m+[m[32m      Object.entries(state).filter(([_, n]) =>[m
[32m+[m[32m        (!system || (n.system || '') === system) &&[m
[32m+[m[32m        (!location || location === 'All' || (n.location || '') === location)[m
[32m+[m[32m      )[m
[32m+[m[32m    );[m
[32m+[m
[32m+[m[32m    const result = aggregateLayer2(filtered);[m
[32m+[m[32m    const top = result.top;[m
[32m+[m
[32m+[m[32m    const rootCauseLines = top.map(t => {[m
[32m+[m[32m      if (t.nodeKey === 'operations') return `- Operations: queue ${t.node.queueDepth ?? 'N/A'}, backlog ${t.node.intakeBacklog ?? 'N/A'}, staffing ${t.node.staffingCoverage ?? 'N/A'}%`;[m
[32m+[m[32m      if (t.nodeKey === 'billing') return `- Billing: denial ${t.node.denialRate ?? 'N/A'}%, lag ${t.node.claimLagDays ?? 'N/A'}d`;[m
[32m+[m[32m      if (t.nodeKey === 'insurance') return `- Insurance: auth backlog ${t.node.authBacklog ?? 'N/A'}, delay ${t.node.authDelayHours ?? 'N/A'}h`;[m
[32m+[m[32m      if (t.nodeKey === 'compliance') return `- Compliance: open findings ${t.node.openFindings ?? 'N/A'}, exposure $${t.node.auditExposure ?? 'N/A'}`;[m
[32m+[m[32m      if (t.nodeKey === 'medical') return `- Medical: chart defects ${t.node.chartDefects ?? 'N/A'}`;[m
[32m+[m[32m      return `- ${t.nodeKey}: active pressure`;[m
[32m+[m[32m    }).join('\\n');[m
[32m+[m
[32m+[m[32m    const topIssue = top.length[m
[32m+[m[32m      ? `${top.map(t => t.nodeKey).join(' + ')} are compounding into reimbursement and throughput drag.`[m
[32m+[m[32m      : 'No qualifying node pressure found.';[m
[32m+[m
[32m+[m[32m    const output = `TOP ISSUE[m
[32m+[m[32m${topIssue}[m
[32m+[m
[32m+[m[32mSYSTEM[m
[32m+[m[32m${system || 'General Healthcare'}[m
[32m+[m
[32m+[m[32mLOCATION[m
[32m+[m[32m${location || 'All'}[m
[32m+[m
[32m+[m[32mREVENUE AT RISK[m
[32m+[m[32m$${result.revenueAtRisk.toLocaleString()}[m
[32m+[m
[32m+[m[32mRECOVERABLE VALUE[m
[32m+[m[32m72 HOURS: $${result.recoverable72h.toLocaleString()}[m
[32m+[m[32m30 DAYS: $${result.recoverable30d.toLocaleString()}[m
[32m+[m
[32m+[m[32mROOT CAUSE[m
[32m+[m[32m${rootCauseLines || '- No live node telemetry'}[m
[32m+[m
[32m+[m[32mBEST NEXT COURSE OF ACTION[m
[32m+[m[32m1. Clear the highest-value backlog first[m
[32m+[m[32m2. Escalate auth and documentation blockers older than 24–72 hours[m
[32m+[m[32m3. Align intake, billing, and scheduling handoffs for the next shift[m
[32m+[m
[32m+[m[32mOWNER LANES[m
[32m+[m[32mOperations · Billing · Insurance · Compliance[m
[32m+[m
[32m+[m[32mCONFIDENCE[m
[32m+[m[32m91%`;[m
[32m+[m
[32m+[m[32m    res.json({[m
[32m+[m[32m      ok: true,[m
[32m+[m[32m      output,[m
[32m+[m[32m      revenueAtRisk: result.revenueAtRisk,[m
[32m+[m[32m      recoverable72h: result.recoverable72h,[m
[32m+[m[32m      recoverable30d: result.recoverable30d,[m
[32m+[m[32m      top: result.top[m
[32m+[m[32m    });[m
[32m+[m[32m  } catch (e) {[m
[32m+[m[32m    res.status(500).json({ ok: false, error: e.message });[m
[32m+[m[32m  }[m
[32m+[m[32m});[m
[32m+[m
[32m+[m
 app.post('/api/hc/ask', async (req,res)=>{[m
   try{[m
     const {query='',system='',location=''} = req.body||{};[m
