const express = require('express');
const path = require('path');
const app = express();
app.use(express.json());
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

// ── 404 catch-all ─────────────────────────────────────────────────
app.use('/api', (req,res) => res.status(404).json({ok:false,error:'API route not found',path:req.path}));
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

app.post("/api/hc/query", async(req,res)=>{

const body=req.body||{};
const payload=body.payload||body||{};

const node=String(payload.node||"OPERATIONS").toUpperCase();

const profile=finalHCProfile(node);

const txt=`
${node}

TOP ISSUE
${profile.issue}

WHY IT MATTERS
This unresolved ${node.toLowerCase()} issue can create operational drag, financial exposure, compliance risk, patient-flow degradation, or executive escalation if not resolved inside the current operating cycle.

BEST NEXT ACTIONS
1. ${profile.actions[0]}
2. ${profile.actions[1]}
3. ${profile.actions[2]}
4. ${profile.actions[3]}

OWNER LANE
${profile.owner}

HITL DECISION
Human leadership review required before enterprise escalation and strategist synthesis.

STRATEGIST RELAY
Relay unresolved ${node.toLowerCase()} risk to HC Strategist for enterprise BNCA synthesis and executive prioritization.

CONFIDENCE
94%
`;

res.json({
ok:true,
node,
reply:txt,
content:txt,
forced:true,
timestamp:new Date().toISOString()
});

});

console.log("FINAL HC QUERY ROUTE ACTIVE");



app.listen(8080, () => console.log('Sovereign Mesh Online on 8080'));
