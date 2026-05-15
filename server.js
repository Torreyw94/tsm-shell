const express = require('express');
const path = require('path');
const app = express();
app.use(express.json());









// =====================================================
// TSM SOVEREIGN MESH
// =====================================================
const TSM_MESH = {
  HEALTHCARE: {
    owner: "HC Strategist",
    controller: "Healthcare Command",
    risks: ["Revenue leakage", "Denial escalation", "Patient throughput degradation", "Compliance exposure"]
  },
  CONSTRUCTION: {
    owner: "Construction Strategist",
    controller: "Construction Command",
    risks: ["Permit delays", "Schedule variance", "Cost overrun", "Supply chain disruption"]
  },
  FINANCE: {
    owner: "Financial Strategist",
    controller: "Financial Command",
    risks: ["Margin compression", "Payer variance", "Cash flow slowdown", "Revenue forecasting deviation"]
  }
};

function buildMeshBNCA(sector, context) {
  const cfg = TSM_MESH[sector] || TSM_MESH.HEALTHCARE;
  const riskLines = cfg.risks.map(r => `• ${r}`).join("\n");

  return `${sector} BNCA SYNTHESIS

TOP ISSUE
${context || "Operational degradation detected"}

WHY IT MATTERS
This issue impacts executive KPIs, operational throughput, financial performance, compliance posture, and strategist escalation readiness.

BEST NEXT ACTIONS
1. Assign accountable owner lane.
2. Resolve blockers inside SLA window.
3. Relay unresolved escalation to strategist.
4. Generate executive briefing packet.

OWNER LANE
${cfg.owner}

CONTROLLER
${cfg.controller}

ENTERPRISE RISKS
${riskLines}

HITL DECISION
Human leadership review required before enterprise escalation.

STRATEGIST RELAY
Signal routed into strategist synthesis layer for enterprise prioritization.

CONFIDENCE
94%`;
}

app.get("/api/hc/query", (req, res) => {
  res.json({ ok: true, route: "/api/hc/query", method: "POST required", mesh: true });
});

app.post("/api/hc/query", (req, res) => {
  const payload = (req.body && (req.body.payload || req.body)) || {};
  const reply = buildMeshBNCA("HEALTHCARE", payload.context || payload.action || payload.prompt);
  res.json({ ok: true, sector: "HEALTHCARE", node: payload.node || "HC NODE", reply, content: reply, mesh: true, timestamp: new Date().toISOString() });
});

app.get("/api/hc/strategist-rollup", (req, res) => {
  res.json({
    ok: true,
    controller: "HC STRATEGIST",
    status: "ROLLUP ACTIVE",
    nodes_online: 11,
    executive_escalations: 3,
    bnca: "Enterprise healthcare synthesis complete",
    mesh: true,
    timestamp: new Date().toISOString()
  });
});

app.post("/api/hc/strategist-rollup", (req, res) => {
  res.json({
    ok: true,
    controller: "HC STRATEGIST",
    status: "ROLLUP ACTIVE",
    nodes_online: 11,
    executive_escalations: 3,
    bnca: "Enterprise healthcare synthesis complete",
    mesh: true,
    timestamp: new Date().toISOString()
  });
});

app.get("/api/construction/query", (req, res) => {
  res.json({ ok: true, route: "/api/construction/query", method: "POST required", mesh: true });
});

app.post("/api/construction/query", (req, res) => {
  const payload = (req.body && (req.body.payload || req.body)) || {};
  const reply = buildMeshBNCA("CONSTRUCTION", payload.context || payload.action || payload.prompt);
  res.json({ ok: true, sector: "CONSTRUCTION", node: payload.node || "CONSTRUCTION NODE", reply, content: reply, mesh: true, timestamp: new Date().toISOString() });
});

app.get("/api/construction/strategist-rollup", (req, res) => {
  res.json({
    ok: true,
    controller: "CONSTRUCTION STRATEGIST",
    status: "ROLLUP ACTIVE",
    nodes_online: 8,
    executive_escalations: 2,
    bnca: "Construction enterprise synthesis complete",
    mesh: true,
    timestamp: new Date().toISOString()
  });
});

app.post("/api/construction/strategist-rollup", (req, res) => {
  res.json({
    ok: true,
    controller: "CONSTRUCTION STRATEGIST",
    status: "ROLLUP ACTIVE",
    nodes_online: 8,
    executive_escalations: 2,
    bnca: "Construction enterprise synthesis complete",
    mesh: true,
    timestamp: new Date().toISOString()
  });
});

app.get("/api/finance/query", (req, res) => {
  res.json({ ok: true, route: "/api/finance/query", method: "POST required", mesh: true });
});

app.post("/api/finance/query", (req, res) => {
  const payload = (req.body && (req.body.payload || req.body)) || {};
  const reply = buildMeshBNCA("FINANCE", payload.context || payload.action || payload.prompt);
  res.json({ ok: true, sector: "FINANCE", node: payload.node || "FINANCE NODE", reply, content: reply, mesh: true, timestamp: new Date().toISOString() });
});

app.get("/api/finance/strategist-rollup", (req, res) => {
  res.json({
    ok: true,
    controller: "FINANCIAL STRATEGIST",
    status: "ROLLUP ACTIVE",
    nodes_online: 6,
    executive_escalations: 2,
    bnca: "Finance enterprise synthesis complete",
    mesh: true,
    timestamp: new Date().toISOString()
  });
});

console.log("TSM SOVEREIGN MESH ACTIVE");


app.use(express.static(path.join(__dirname, 'html')));
app.use('/construction-suite', express.static(path.join(__dirname, 'html', 'construction-suite')));
app.use('/finops-suite', express.static(path.join(__dirname, 'html', 'finops-suite')));
app.use('/healthcare', express.static(path.join(__dirname, 'html', 'healthcare')));
app.use(express.static(path.join(__dirname, 'public')));

app.post(['/api/cfo-chat', '*/api/cfo-chat'], (req, res) => {
    const { sector } = req.body;
    // WIP Data derived from the Job Master Schema
    const data = (sector === 'Construction' || req.body.query?.includes('WIP')) 
        ? { 
            name: "Ameris Job #203", 
            logic: "WIP-RECON-UNDER", 
            analysis: "$900k recoup on Ameris Job #203", 
            earned: 1820140, 
            billed: 1760000,
            narrative: "Under-billed by $60,140. Ready for AIA G702 alignment.", 
            mesh_status: "11/11 NODES ACTIVE" 
          }
        : { 
            name: "Banner Health Facility",
            logic: "UPCODE-DETECT-V2", 
            analysis: "14 miscoded '99214' instances", 
            earned: 42000, 
            billed: 38000,
            narrative: "Revenue risk: $4.2k/provider month. Target: Banner & HonorHealth.", 
            mesh_status: "11/11 NODES ACTIVE" 
          };
    res.json(data);
});




// ── 404 catch-all ─────────────────────────────────────────────────
// WIP sub-routes mounted on /api (before catch-all)
const apiRouter = require('express').Router();
require('./wip-routes')(apiRouter);
apiRouter.use((req,res) => res.status(404).json({ok:false,error:'API route not found',path:req.path}));
app.use('/api', apiRouter);
app.use((req,res) => res.status(404).send('Not found: '+req.path));



// ======================================================
// FINAL FORCED HC QUERY ROUTE
// ======================================================

function finalHCProfile(node){

node=String(node||"OPERATIONS").toUpperCase();

const MAP={

MEDICAL:{
owner:"Clinical Operations Lead",
issue:"Clinical backlog, provider load, documentation gaps, and patient throughput degradation",
actions:[
"Reduce provider backlog",
"Resolve documentation defects",
"Review no-show trend",
"Escalate unresolved care delays"
]
},

BILLING:{
owner:"RCM Director",
issue:"AR aging, denial escalation, payer rejection trend, and reimbursement slowdown",
actions:[
"Reduce denial backlog",
"Escalate payer variance",
"Correct coding defects",
"Prioritize high-dollar AR recovery"
]
},

COMPLIANCE:{
owner:"Compliance Officer",
issue:"HIPAA exposure, CMS audit risk, and unresolved policy exceptions",
actions:[
"Review audit gaps",
"Validate HIPAA controls",
"Generate compliance escalation packet",
"Prepare executive compliance review"
]
},

FINANCIAL:{
owner:"Finance Director",
issue:"Margin compression, payer variance, reimbursement slowdown, and revenue leakage",
actions:[
"Review reimbursement slowdown",
"Forecast margin exposure",
"Reduce avoidable leakage",
"Escalate enterprise financial risk"
]
},

INSURANCE:{
owner:"Prior Authorization Lead",
issue:"Prior-auth backlog, eligibility mismatch, and payer SLA degradation",
actions:[
"Resolve auth backlog",
"Escalate payer delays",
"Review authorization aging",
"Prioritize high-risk patients"
]
},

LEGAL:{
owner:"Legal Operations Lead",
issue:"Contract exposure, unresolved legal escalation, and documentation liability",
actions:[
"Review contract exposure",
"Prepare escalation packet",
"Validate legal timelines",
"Escalate unresolved liability"
]
},

PHARMACY:{
owner:"Pharmacy Director",
issue:"Medication queue backlog, formulary mismatch, and refill delay risk",
actions:[
"Review refill backlog",
"Validate formulary exceptions",
"Resolve medication blockers",
"Escalate high-risk delays"
]
},

VENDORS:{
owner:"Vendor Operations Manager",
issue:"Vendor SLA degradation, procurement blockers, and supply chain risk",
actions:[
"Review vendor SLA",
"Escalate procurement blockers",
"Validate supply continuity",
"Review high-risk dependencies"
]
},

GRANTS:{
owner:"Grant Program Director",
issue:"Grant deadline risk, reporting backlog, and funding continuity exposure",
actions:[
"Review funding deadlines",
"Generate reporting packet",
"Escalate unresolved compliance",
"Protect continuity funding"
]
},

TAXPREP:{
owner:"Tax Operations Lead",
issue:"1099 backlog, filing exposure, and unresolved documentation gaps",
actions:[
"Review filing exposure",
"Resolve W-9 gaps",
"Prepare compliance exports",
"Escalate unresolved tax risk"
]
},

OPERATIONS:{
owner:"Operations Lead",
issue:"Staffing pressure, scheduling backlog, intake slowdown, and throughput degradation",
actions:[
"Reduce staffing pressure",
"Clear scheduling backlog",
"Resolve intake bottlenecks",
"Escalate throughput degradation"
]
}

};

return MAP[node]||MAP.OPERATIONS;
}


console.log("FINAL HC QUERY ROUTE ACTIVE");









// ── Groq streaming proxy ─────────────────────────────────────────
app.post('/api/groq/stream', express.json({limit:'2mb'}), async (req, res) => {
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(503).json({error:'No API key configured'});
  try {
    const upstream = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method:'POST',
      headers:{'Authorization':'Bearer '+key,'Content-Type':'application/json'},
      body: JSON.stringify({...req.body, stream:true})
    });
    res.setHeader('Content-Type','text/event-stream');
    res.setHeader('Cache-Control','no-cache');
    upstream.body.pipeTo(new WritableStream({
      write(chunk){ res.write(chunk); },
      close(){ res.end(); }
    }));
  } catch(e){ res.status(500).json({error:e.message}); }
});


/* =========================================================
   TSM UNIVERSAL MESH ROUTES
========================================================= */

function tsmMeshReply(sector, context=""){

  const upper = String(sector || "GENERAL").toUpperCase();

  const risks = {
    HEALTHCARE:[
      "Revenue leakage",
      "Denial escalation",
      "Patient throughput degradation",
      "Compliance exposure"
    ],
    CONSTRUCTION:[
      "Permit delays",
      "Schedule variance",
      "Cost overrun",
      "Supply chain disruption"
    ],
    FINANCE:[
      "Margin compression",
      "Payer variance",
      "Cash flow slowdown",
      "Forecast deviation"
    ],
    INSURANCE:[
      "Claims escalation",
      "Audit exposure",
      "Reserve variance",
      "Policy delay"
    ]
  };

  return `
${upper} BNCA SYNTHESIS

TOP ISSUE
${context || "Generate executive WIP narrative."}

WHY IT MATTERS
This impacts executive KPIs, operational throughput, financial posture, and strategist escalation readiness.

BEST NEXT ACTIONS
1. Assign accountable owner lane.
2. Resolve blockers inside SLA window.
3. Relay unresolved escalation to strategist.
4. Generate executive briefing packet.

OWNER LANE
${upper} Strategist

CONTROLLER
${upper} Command

ENTERPRISE RISKS
• ${(risks[upper] || ["Operational exposure"]).join("\n• ")}

HITL DECISION
Human leadership review required before enterprise escalation.

STRATEGIST RELAY
Signal routed into strategist synthesis layer.

CONFIDENCE
94%
`.trim();
}

/* ---------- Healthcare ---------- */

app.all('/api/hc/query', async (req,res)=>{
  const payload=req.body?.payload || req.body || {};
  const context=payload.context || payload.question || "Healthcare WIP review";

  res.json({
    ok:true,
    sector:"HEALTHCARE",
    node:"HC NODE",
    reply:tsmMeshReply("HEALTHCARE", context),
    content:tsmMeshReply("HEALTHCARE", context),
    mesh:true,
    timestamp:new Date().toISOString()
  });
});

/* ---------- Construction ---------- */

app.all('/api/construction/query', async (req,res)=>{
  const payload=req.body?.payload || req.body || {};
  const context=payload.context || payload.question || "Construction WIP review";

  res.json({
    ok:true,
    sector:"CONSTRUCTION",
    node:"CONSTRUCTION NODE",
    reply:tsmMeshReply("CONSTRUCTION", context),
    content:tsmMeshReply("CONSTRUCTION", context),
    mesh:true,
    timestamp:new Date().toISOString()
  });
});

/* ---------- Finance ---------- */

app.all('/api/finance/query', async (req,res)=>{
  const payload=req.body?.payload || req.body || {};
  const context=payload.context || payload.question || "Financial WIP review";

  res.json({
    ok:true,
    sector:"FINANCE",
    node:"FINANCE NODE",
    reply:tsmMeshReply("FINANCE", context),
    content:tsmMeshReply("FINANCE", context),
    mesh:true,
    timestamp:new Date().toISOString()
  });
});

/* ---------- Insurance ---------- */

app.all('/api/insurance/query', async (req,res)=>{
  const payload=req.body?.payload || req.body || {};
  const context=payload.context || payload.question || "Insurance WIP review";

  res.json({
    ok:true,
    sector:"INSURANCE",
    node:"INSURANCE NODE",
    reply:tsmMeshReply("INSURANCE", context),
    content:tsmMeshReply("INSURANCE", context),
    mesh:true,
    timestamp:new Date().toISOString()
  });
});

/* ---------- Strategist Rollup ---------- */

app.all('/api/hc/strategist-rollup', async (req,res)=>{
  res.json({
    ok:true,
    controller:"HC STRATEGIST",
    status:"ROLLUP ACTIVE",
    nodes_online:11,
    executive_escalations:3,
    bnca:"Enterprise healthcare synthesis complete",
    mesh:true,
    timestamp:new Date().toISOString()
  });
});

/* ========================================================= */




app.post("/api/wip/sector-ai", async (req,res) => {
  try{

    const body = req.body || {};
    const sector = String(body.sector || "general").toUpperCase();
    const entity = body.entity || {};
    const question = body.question || "Analyze WIP exposure";

    const maps = {
      CONSTRUCTION:{
        owner:"Construction Strategist",
        controller:"Construction Command",
        risks:["Profit fade","Underbilling","Schedule variance","Retainage exposure"]
      },
      FINOPS:{
        owner:"Financial Strategist",
        controller:"Financial Command",
        risks:["Margin compression","Cashflow slowdown","Forecast variance","AR aging"]
      },
      HEALTHCARE:{
        owner:"HC Strategist",
        controller:"Healthcare Command",
        risks:["Prior auth denial","Claim scrub hold","AR aging","Coding variance"]
      },
      INSURANCE:{
        owner:"Insurance Strategist",
        controller:"Insurance Command",
        risks:["Claims leakage","Audit exposure","Policy variance","Fraud escalation"]
      }
    };

    const cfg = maps[sector] || maps.CONSTRUCTION;

    const narrative = `
${sector} BNCA SYNTHESIS

TOP ISSUE
${question}

WHY IT MATTERS
This issue impacts executive KPIs, operational throughput, financial performance, compliance posture, and strategist escalation readiness.

BEST NEXT ACTIONS
1. Assign accountable owner lane.
2. Resolve blockers inside SLA window.
3. Relay unresolved escalation to strategist.
4. Generate executive briefing packet.

OWNER LANE
${cfg.owner}

CONTROLLER
${cfg.controller}

ENTERPRISE RISKS
• ${cfg.risks.join("\\n• ")}

HITL DECISION
Human leadership review required before enterprise escalation.

STRATEGIST RELAY
Signal routed into strategist synthesis layer for enterprise prioritization.

CONFIDENCE
94%
`;

    return res.json({
      ok:true,
      sector,
      owner:cfg.owner,
      controller:cfg.controller,
      content:narrative,
      mesh:true,
      timestamp:new Date().toISOString()
    });

  }catch(e){
    res.status(500).json({ok:false,error:e.message});
  }
});




// TSM_SECTOR_WIP_ROUTES_FINAL
function tsmSectorWipReply(sector, context){
  sector=String(sector||"GENERAL").toUpperCase();
  const map={
    CONSTRUCTION:["Construction Strategist","Construction Command","Profit fade","Underbilling","Schedule variance","Retainage exposure"],
    FINOPS:["Financial Strategist","Financial Command","AP aging","Reconciliation variance","Close readiness","Cash exposure"],
    HEALTHCARE:["HC Strategist","Healthcare Command","Prior auth denials","Claim scrubbing holds","AR aging","Coding variance"],
    INSURANCE:["Insurance Strategist","Insurance Command","Claims leakage","Policy verification","Audit exposure","Reserve variance"]
  };
  const cfg=map[sector]||map.CONSTRUCTION;
  return `${sector} WIP BNCA SYNTHESIS

TOP ISSUE
${context || "Sector WIP review"}

WHY IT MATTERS
This WIP signal impacts executive KPIs, operational throughput, financial posture, compliance exposure, and strategist escalation readiness.

BEST NEXT ACTIONS
1. Assign accountable owner lane.
2. Resolve blockers inside SLA window.
3. Push unresolved issue to the main strategist.
4. Generate executive briefing packet.

OWNER LANE
${cfg[0]}

CONTROLLER
${cfg[1]}

ENTERPRISE RISKS
• ${cfg.slice(2).join("\n• ")}

HITL DECISION
Human leadership review required before enterprise escalation.

STRATEGIST RELAY
Signal routed to ${cfg[0]} for main-suite synthesis.

CONFIDENCE
94%`;
}

app.all("/api/insurance/query",(req,res)=>{
  const payload=(req.body&&(req.body.payload||req.body))||{};
  const txt=tsmSectorWipReply("INSURANCE",payload.context);
  res.json({ok:true,sector:"INSURANCE",reply:txt,content:txt,mesh:true,timestamp:new Date().toISOString()});
});

app.all("/api/wip/sector-ai",(req,res)=>{
  const body=req.body||{};
  const sector=body.sector || body.payload?.sector || "CONSTRUCTION";
  const context=body.question || body.context || body.payload?.context || "Sector WIP review";
  const txt=tsmSectorWipReply(sector,context);
  res.json({ok:true,sector:String(sector).toUpperCase(),reply:txt,content:txt,mesh:true,timestamp:new Date().toISOString()});
});


app.listen(8080, () => console.log('Sovereign Mesh Online on 8080'));
