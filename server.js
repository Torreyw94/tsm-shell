const express = require("express");
const path = require("path");
const fs = require("fs");

const app = express();
const PORT = process.env.PORT || 8080;
const HTML_ROOT = path.join(__dirname, "html");

app.get("/health", (_req, res) => res.json({ status: "ok" }));

const suites = [
  { route: "/construction", dir: "construction-suite", index: "construction-hub.html" },
  { route: "/finops",       dir: "finops-suite",       index: "finops-presentation/index.html" },
  { route: "/healthcare",   dir: "healthcare",          index: "index.html" },
  { route: "/insurance",    dir: "tsm-insurance",       index: "ins-presentation.html" },
  { route: "/music",        dir: "music-command",       index: "index.html" },
];

suites.forEach(({ route, dir, index }) => {
  const suiteDir = path.join(HTML_ROOT, dir);
  if (!fs.existsSync(suiteDir)) console.warn(`⚠️  Not found: ${suiteDir}`);
  const serveIndex = (_req, res) => {
    res.sendFile(path.join(suiteDir, index), (err) => {
      if (err) res.status(404).send(`Index not found: ${index}`);
    });
  };
  app.get(route, serveIndex);
  app.get(route + "/", serveIndex);
  app.use(route + "/", express.static(suiteDir, { extensions: ["html"] }));
  console.log(`✅  ${route} → ${dir}/${index}`);
});

app.get("/", (_req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>TSM Shell</title>
  <style>
    body{font-family:system-ui,sans-serif;background:#0d1117;color:#e6edf3;
         display:flex;flex-direction:column;align-items:center;
         justify-content:center;min-height:100vh;margin:0}
    h1{font-size:2rem;margin-bottom:.5rem}
    p{color:#8b949e;margin-bottom:2rem}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));
          gap:1rem;width:min(900px,90vw)}
    a.card{background:#161b22;border:1px solid #30363d;border-radius:12px;
           padding:1.5rem;text-decoration:none;color:inherit;transition:.2s}
    a.card:hover{border-color:#58a6ff;background:#1c2128}
    a.card h2{margin:0 0 .4rem;font-size:1.1rem}
    a.card p{margin:0;font-size:.85rem;color:#8b949e}
  </style>
</head>
<body>
  <h1>TSM Shell</h1>
  <p>Select a suite to continue</p>
  <div class="grid">
    <a class="card" href="/construction"><h2>🏗️ Construction</h2><p>Command, legal, financial &amp; compliance</p></a>
    <a class="card" href="/finops"><h2>💰 FinOps Suite</h2><p>Financial operations, tax &amp; compliance</p></a>
    <a class="card" href="/healthcare"><h2>🏥 Healthcare</h2><p>15-node mesh: billing, insurance, pharmacy</p></a>
    <a class="card" href="/insurance"><h2>🛡️ TSM Insurance</h2><p>Agent portal, AZ, DME, pricing &amp; legal</p></a>
    <a class="card" href="/music"><h2>🎵 Music Command</h2><p>App, demo conductor, marketing &amp; presentation</p></a>
  </div>
</body>
</html>`);
});

app.use((req, res) => res.status(404).send(`<pre>404 — Not found: ${req.path}</pre>`));


// ======================================================
// TSM HEALTHCARE REAL AI CHAIN · HC COMMAND → HC STRATEGIST → MAIN STRATEGIST → EXEC PORTAL
// Server-side only. No provider/model/key exposed in browser.
// ======================================================
async function tsmAIJSON(prompt, fallback){
  try{
    if(!process.env.GROQ_API_KEY) throw new Error("GROQ_API_KEY missing");

    const r = await fetch('https://api.groq.com/openai/v1/chat/completions',{
      method:'POST',
      headers:{
        'Authorization':`Bearer ${process.env.GROQ_API_KEY}`,
        'Content-Type':'application/json'
      },
      body:JSON.stringify({
        model:process.env.TSM_MODEL || process.env.TSM_FINOPS_MODEL || 'llama-3.3-70b-versatile',
        messages:[
          {role:'system',content:'You are TSM Neural Core. Never mention provider, model, API, or implementation. Return JSON only.'},
          {role:'user',content:prompt}
        ],
        temperature:.22,
        max_tokens:1200
      })
    });

    if(!r.ok) throw new Error("AI unavailable");
    const data=await r.json();
    const text=data?.choices?.[0]?.message?.content || "";
    try{return JSON.parse(text.replace(/```json|```/g,'').trim());}
    catch(e){return {...fallback, narrative:text};}
  }catch(e){
    return {...fallback, ai_status:'fallback_no_mock_data_key_or_route_needed'};
  }
}

const TSM_MEMORY = global.__TSM_MEMORY__ = global.__TSM_MEMORY__ || {
  healthcare:{nodes:{}, hcStrategist:null, mainStrategist:null, executive:null}
};

app.get('/api/hc/nodes',(req,res)=>{
  res.json({ok:true,status:'HC node route online',nodes:['operations','billing','medical','pharmacy','financial','legal','vendors','compliance','tax-prep','grants','insurance']});
});

app.post('/api/hc/node/:node', async (req,res)=>{
  const node=req.params.node;
  const payload=req.body || {};
  const prompt=`Analyze this healthcare node for Office Manager readiness.

Node: ${node}
Payload: ${JSON.stringify(payload).slice(0,4000)}

Return JSON:
{
 "node":"${node}",
 "status":"READY|WATCH|RISK",
 "top_issue":"...",
 "findings":["..."],
 "actions":["..."],
 "bnca":"Best Next Course of Action for office manager",
 "owner_lane":"office manager|billing|compliance|medical|financial|vendor|executive",
 "confidence":0-100
}`;

  const result=await tsmAIJSON(prompt,{
    node,status:'WATCH',top_issue:'Node requires review',findings:[],actions:[],bnca:'Review node output and assign owner lane.',owner_lane:'office manager',confidence:80
  });

  TSM_MEMORY.healthcare.nodes[node]=result;
  res.json({ok:true,node,result,ts:new Date().toISOString()});
});

app.post('/api/hc/bnca', async (req,res)=>{
  const payload=req.body || {};
  const prompt=`You are Healthcare Command Center Office Manager Edition.

Use all available HC node context and payload to generate BNCA.

HC node memory:
${JSON.stringify(TSM_MEMORY.healthcare.nodes).slice(0,6000)}

Payload:
${JSON.stringify(payload).slice(0,4000)}

Return JSON:
{
 "suite":"healthcare-command",
 "top_issue":"...",
 "risk_level":"READY|WATCH|RISK|URGENT",
 "node_summary":["..."],
 "bnca":"...",
 "owner_lanes":["..."],
 "hitl_review_required":true,
 "confidence":0-100
}`;

  const result=await tsmAIJSON(prompt,{
    suite:'healthcare-command',top_issue:'Healthcare operations require review',risk_level:'WATCH',node_summary:[],bnca:'Prioritize billing/auth/compliance blockers and assign owner lanes.',owner_lanes:['office manager'],hitl_review_required:true,confidence:82
  });

  TSM_MEMORY.healthcare.hcCommand=result;
  res.json({ok:true,result,ts:new Date().toISOString()});
});

app.post('/api/hc-strategist/bnca', async (req,res)=>{
  const payload=req.body || {};
  const prompt=`You are HC Strategist.

Take Healthcare Command BNCA and node outputs, synthesize strategist recommendation.

Healthcare memory:
${JSON.stringify(TSM_MEMORY.healthcare).slice(0,8000)}

Payload:
${JSON.stringify(payload).slice(0,4000)}

Return JSON:
{
 "suite":"hc-strategist",
 "strategic_summary":"...",
 "priority_actions":[{"rank":1,"issue":"...","owner":"...","why_now":"..."}],
 "bnca":"...",
 "relay_to_main_strategist":true,
 "confidence":0-100
}`;

  const result=await tsmAIJSON(prompt,{
    suite:'hc-strategist',strategic_summary:'HC Strategist review needed.',priority_actions:[],bnca:'Relay healthcare recommendation to Main Strategist.',relay_to_main_strategist:true,confidence:82
  });

  TSM_MEMORY.healthcare.hcStrategist=result;
  res.json({ok:true,result,ts:new Date().toISOString()});
});

app.post('/api/main-strategist/healthcare', async (req,res)=>{
  const payload=req.body || {};
  const prompt=`You are Main Strategist.

Convert HC Strategist output into executive decision package for CFO / decision makers.

Healthcare memory:
${JSON.stringify(TSM_MEMORY.healthcare).slice(0,9000)}

Payload:
${JSON.stringify(payload).slice(0,4000)}

Return JSON:
{
 "suite":"main-strategist",
 "executive_issue":"...",
 "financial_or_operational_impact":"...",
 "recommendation":"...",
 "decision_options":["..."],
 "hitl_relay":"What human should say to CFO/decision maker",
 "send_to_executive_portal":true,
 "confidence":0-100
}`;

  const result=await tsmAIJSON(prompt,{
    suite:'main-strategist',executive_issue:'Healthcare readiness needs executive review.',financial_or_operational_impact:'Billing/auth/compliance pressure may affect throughput and revenue.',recommendation:'Start with office manager workflow pilot.',decision_options:['30-day pilot','technical walkthrough'],hitl_relay:'Review BNCA and confirm owner lanes.',send_to_executive_portal:true,confidence:84
  });

  TSM_MEMORY.healthcare.mainStrategist=result;
  res.json({ok:true,result,ts:new Date().toISOString()});
});

app.post('/api/executive/portal', async (req,res)=>{
  const payload=req.body || {};
  const prompt=`You are TSM Executive Portal.

Create HITL-ready executive relay for CFOs and decision makers.

Healthcare memory:
${JSON.stringify(TSM_MEMORY.healthcare).slice(0,10000)}

Payload:
${JSON.stringify(payload).slice(0,4000)}

Return JSON:
{
 "portal":"executive",
 "audience":"CFO / Decision Maker",
 "decision_summary":"...",
 "bnca_recommendation":"...",
 "hitl_script":"...",
 "approval_path":["..."],
 "next_step":"...",
 "confidence":0-100
}`;

  const result=await tsmAIJSON(prompt,{
    portal:'executive',audience:'CFO / Decision Maker',decision_summary:'Healthcare BNCA ready for executive review.',bnca_recommendation:'Approve pilot workflow focused on billing/auth/compliance throughput.',hitl_script:'Here is the action-ready recommendation and the owner lanes we need approved.',approval_path:['Office Manager','CFO','Operations Lead'],next_step:'Book walkthrough or approve 30-day pilot.',confidence:85
  });

  TSM_MEMORY.healthcare.executive=result;
  res.json({ok:true,result,ts:new Date().toISOString()});
});

app.get('/executive-portal',(req,res)=>res.redirect('/html/executive-portal/index.html'));
app.get('/healthcare/executive-portal',(req,res)=>res.redirect('/html/executive-portal/index.html'));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`\n🚀 TSM Shell on http://0.0.0.0:${PORT}`);
  suites.forEach(s => console.log(`   ${s.route} → ${s.dir}/${s.index}`));
  console.log();
});
