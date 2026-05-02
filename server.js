const express = require("express");
const path = require("path");
const fs = require("fs");

const app = express();
app.use(express.json({ limit: '10mb' }));
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

app.use('/exports', express.static(path.join(__dirname, 'exports')));
app.use('/html', express.static(path.join(__dirname, 'html'), { extensions: ['html'] }));

app.use('/html/healthcare', express.static(path.join(__dirname, 'html', 'healthcare'), { index: 'index.html', extensions: ['html'] }));

// Specific route for PoC demo
app.get('/html/healthcare/poc-html', (req, res) => {
  res.sendFile(path.join(__dirname, 'html', 'healthcare', 'poc-html', 'index.html'));
});
app.get('/html/healthcare/poc-html/', (req, res) => {
  res.sendFile(path.join(__dirname, 'html', 'healthcare', 'poc-html', 'index.html'));
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
        model:process.env.TSM_MODEL || 'llama-3.1-8b-instant',
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

async function runAIQuery(body, defaultSystem){
  const system = body.system || defaultSystem || 'You are TSM Neural Core. Answer precisely.';
  const message = body.message || body.question || body.query || body.prompt || '';
  const prompt = `${system}\n\n${message}`.trim();
  const result = await tsmAIJSON(prompt, {
    ok:false,
    response:'AI unavailable',
    ai_status:'fallback_no_mock_data_key_or_route_needed'
  });
  return result;
}

app.post('/api/ai/query', async (req, res) => {
  try {
    const result = await runAIQuery(req.body || {}, 'You are an enterprise AI assistant.');
    res.json({ ok:true, ...result, ts:new Date().toISOString() });
  } catch(e) {
    res.status(500).json({ ok:false, error:e.message });
  }
});

app.post('/api/hc/query', async (req, res) => {
  try {
    const result = await runAIQuery(req.body || {}, 'You are a healthcare AI expert in auth denials, payer appeals, and compliance.');
    res.json({ ok:true, ...result, ts:new Date().toISOString() });
  } catch(e) {
    res.status(500).json({ ok:false, error:e.message });
  }
});

app.post('/api/hc/ask', async (req, res) => {
  try {
    const result = await runAIQuery(req.body || {}, 'You are a healthcare AI expert in auth denials, payer appeals, and compliance.');
    res.json({ ok:true, ...result, ts:new Date().toISOString() });
  } catch(e) {
    res.status(500).json({ ok:false, error:e.message });
  }
});

app.post('/api/main-strategist/hc-report', async (req,res)=>{
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

app.post('/api/honor/dee/dashboard', async (req,res)=>{
  try {
    const body=req.body || {};
    const prompt=`You are HonorHealth dee dashboard AI. Use the provided payload to summarize workflow, denial patterns, and appeal strategy.`;
    const result = await tsmAIJSON(prompt,{ok:false,response:'AI unavailable',ai_status:'fallback_no_mock_data_key_or_route_needed'});
    res.json({ok:true, ...result, ts:new Date().toISOString()});
  } catch(e) {
    res.status(500).json({ok:false,error:e.message});
  }
});

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


// HEALTHCARE CLIENT PRESENTATION + ROUTE ALIASES
app.get('/healthcare-client-presentation',(req,res)=>res.redirect('/html/healthcare-client-presentation/index.html'));

function sendFirstExisting(res, files){
  const path = require('path');
  const fs = require('fs');
  for(const f of files){
    const full = path.join(__dirname,f);
    if(fs.existsSync(full)) return res.sendFile(full);
  }
  return res.status(404).send('<pre>Healthcare file not found</pre>');
}

app.get('/healthcare/',(req,res)=>sendFirstExisting(res,[
  'html/healthcare/index.html',
  'html/healthcare-command/index.html',
  'html/hc-command/index.html'
]));

app.get('/healthcare/hc-strategist/',(req,res)=>sendFirstExisting(res,[
  'html/healthcare/hc-strategist/index.html',
  'html/hc-strategist/index.html'
]));

app.get('/healthcare/hc-main-strategist/',(req,res)=>sendFirstExisting(res,[
  'html/healthcare/hc-main-strategist/index.html',
  'html/hc-main-strategist/index.html',
  'html/healthcare-main-strategist/index.html'
]));

app.get('/healthcare/hc-presentation/',(req,res)=>sendFirstExisting(res,[
  'html/healthcare/hc-presentation/index.html',
  'html/healthcare-presentation/index.html'
]));

// Music API endpoints
app.post("/api/music/revision/run", async (req, res) => {
  try {
    const body = req.body || {};
    const lyrics = body.lyrics || body.draft || body.input || body.text || body.prompt || "";
    const { agent="ZAY" } = body;
    if (!lyrics) return res.status(400).json({ ok: false, error: "Missing lyrics" });
    const result = await tsmAIJSON(`You are music agent ${agent}. Revise these lyrics. Return JSON: { revised, cadence, emotion, structure, imagery, decision }. Lyrics: ${lyrics}`,{ revised: lyrics, cadence: 75, emotion: 75, structure: 75, imagery: 75, decision: "No change" });
    res.json({ ok: true, ...result });
  } catch(e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});


app.post('/api/music/guidance', express.json(), async (req, res) => {
  const { lyrics, step, dna } = req.body;
  const stepNames = {1:'Drop Idea',2:'Pick Version',3:'Refine',4:'Lock Hook',5:'Export'};
  const result = await tsmAIJSON(
    `You are ZAY, an elite music AI coach. User is on Step ${step} (${stepNames[step]||step}).\nLyrics:\n${lyrics||'(none yet)'}\nDNA: ${JSON.stringify(dna||{})}\nGive ONE sharp specific actionable tip for this step. Max 2 sentences. Be direct and musical. Return JSON: { tip, action }`,
    { tip: "Keep going — your instincts are strong.", action: "Run the chain to see what the agents suggest." }
  );
  res.json({ ok: true, ...result });
});

app.post('/api/music/structure', express.json(), async (req, res) => {
  const { lyrics, mood, bpm, key, context } = req.body || {};
  const result = await tsmAIJSON(
    `You are a professional music producer and songwriter. Analyze these lyrics and break them into song sections. Also suggest instrumental details.
Lyrics: ${lyrics}
Artist context: ${JSON.stringify(context||{})}

Return JSON:
{
  "verse": "the verse lines",
  "hook": "the catchiest 1-2 lines that repeat",
  "bridge": "a contrasting section that adds depth",
  "ad_libs": ["short ad-lib 1", "short ad-lib 2", "short ad-lib 3"],
  "instrumental": {
    "suggested_bpm": 90,
    "key": "C minor",
    "mood": "dark and motivational",
    "genre": "hip-hop/trap",
    "reference_artists": ["artist1", "artist2"],
    "beat_description": "description of ideal beat"
  },
  "dna_update": {
    "themes": ["theme1", "theme2"],
    "vocab_style": "street/introspective",
    "flow_pattern": "mid-tempo, punchy",
    "signature_phrases": ["phrase1", "phrase2"]
  }
}`,
    {
      verse: lyrics,
      hook: "Hook not generated",
      bridge: "Bridge not generated", 
      ad_libs: ["yeah", "let's go", "uh"],
      instrumental: { suggested_bpm: 90, key: "C minor", mood: "motivational", genre: "hip-hop", reference_artists: [], beat_description: "Hard-hitting drums with melodic elements" },
      dna_update: { themes: [], vocab_style: "street", flow_pattern: "mid-tempo", signature_phrases: [] }
    }
  );
  res.json({ ok: true, ...result });
});

app.post('/api/music/dna/save', express.json(), async (req, res) => {
  const { songTitle, dna_update, scores, lyrics } = req.body || {};
  // In production this would persist to a DB - for now return enriched DNA
  const result = await tsmAIJSON(
    `You are an AI that builds an artist's musical DNA profile. A new song was created with these characteristics:
Title: ${songTitle||'Untitled'}
Scores: ${JSON.stringify(scores||{})}
DNA Update: ${JSON.stringify(dna_update||{})}
Lyrics sample: ${(lyrics||'').slice(0,500)}

Based on this, generate an updated artist DNA profile that will help guide future songs.
Return JSON:
{
  "style_summary": "2 sentence description of this artist's style",
  "strengths": ["strength1", "strength2", "strength3"],
  "growth_areas": ["area1", "area2"],
  "signature_sound": "description",
  "recommended_next": ["suggestion for next song type 1", "suggestion 2"],
  "vocab_bank": ["word1", "word2", "word3", "word4", "word5"]
}`,
    { style_summary: "An artist with strong emotional delivery and street imagery.", strengths: ["Emotion", "Imagery"], growth_areas: ["Structure"], signature_sound: "Raw and authentic", recommended_next: ["Write a bridge-focused track", "Try a melodic hook"], vocab_bank: [] }
  );
  res.json({ ok: true, ...result });
});

// ======================================================
// MUSIC COMMAND COMPAT ROUTES
// Supports restored rich UI: /api/music/state, /agent-pass, /strategy, /song, /dna/save
// ======================================================
const MUSIC_MEMORY = global.__TSM_MUSIC_MEMORY__ = global.__TSM_MUSIC_MEMORY__ || {
  dna:{adlibs:["yeah","let's go","ay"], tone:"confident", style:"performance-ready"},
  history:[]
};

async function musicAI(prompt, mode){
  try{
    if(!process.env.GROQ_API_KEY) throw new Error("missing key");
    const r = await fetch('https://api.groq.com/openai/v1/chat/completions',{
      method:'POST',
      headers:{
        'Authorization':`Bearer ${process.env.GROQ_API_KEY}`,
        'Content-Type':'application/json'
      },
      body:JSON.stringify({
        model:process.env.TSM_MODEL || 'llama-3.1-8b-instant',
        messages:[
          {role:'system',content:'You are TSM Music Command. Never mention provider, model, key, API, or implementation. Help with song structure, hooks, cadence, ad-libs, bridge, and performance polish.'},
          {role:'user',content:`Mode: ${mode || 'creative'}\nPrompt: ${prompt || ''}`}
        ],
        temperature:.58,
        max_tokens:1100
      })
    });
    if(!r.ok) throw new Error("AI unavailable");
    const data = await r.json();
    return data?.choices?.[0]?.message?.content || "";
  }catch(e){
    return `TSM Music Command fallback active.

STRUCTURE:
Intro → Verse 1 → Pre-Hook → Hook → Verse 2 → Bridge → Final Hook → Outro

AD-LIB PLACEMENT:
Use light ad-libs before the hook, stronger callouts after impact lines, and signature tags in the outro.

BRIDGE:
Shift the emotion. Make it the turning point before the final hook.

NEXT ACTION:
Tighten the hook, place ad-libs, strengthen the bridge, then generate a performance-ready final pass.`;
  }
}

app.get('/api/music/state',(req,res)=>{
  res.json({ok:true,state:MUSIC_MEMORY});
});

app.post('/api/music/dna/save',(req,res)=>{
  MUSIC_MEMORY.dna = {...MUSIC_MEMORY.dna, ...(req.body || {})};
  res.json({ok:true,dna:MUSIC_MEMORY.dna});
});

app.post('/api/music/agent-pass', async (req,res) => {
  const prompt = req.body?.prompt || req.body?.message || req.body?.input || '';
  const result = await tsmAIJSON(
    'You are TSM Music Command. Return EXACTLY 3 different lyric options as JSON: {"options":[{"label":"Option 1: [descriptor]","text":"rewritten lyrics"},{"label":"Option 2: [descriptor]","text":"rewritten lyrics"},{"label":"Option 3: [descriptor]","text":"rewritten lyrics"}],"hook_score":85,"cadence_score":88,"lex_score":82}. Task: ' + prompt + '. Each option must have DIFFERENT lyrics. Raw, street, authentic only.',
    {options:[{label:'Option 1',text:prompt},{label:'Option 2',text:prompt},{label:'Option 3',text:prompt}],hook_score:75,cadence_score:75,lex_score:75}
  );
  res.json({ok:true, ...result, output: result.options?.[0]?.text || ''});
});
app.post('/api/music/agent-pass-old', async (req,res)=>{
  const prompt = req.body?.prompt || req.body?.message || req.body?.input || '';
  const response = await musicAI(prompt,'agent-pass');
  MUSIC_MEMORY.history.unshift({type:'agent-pass',prompt,response,ts:new Date().toISOString()});
  MUSIC_MEMORY.history = MUSIC_MEMORY.history.slice(0,50);
  res.json({ok:true,output:response,response,actions:["Structure review","Ad-lib placement","Bridge improvement","Performance polish"],ts:new Date().toISOString()});
});

app.post('/api/music/strategy', async (req,res)=>{
  const prompt = req.body?.prompt || req.body?.message || req.body?.input || 'Create a release/demo strategy.';
  const response = await musicAI(prompt,'strategy');
  res.json({ok:true,response,ts:new Date().toISOString()});
});

app.post('/api/music/song', async (req,res)=>{
  const prompt = req.body?.prompt || req.body?.lyrics || req.body?.input || 'Create a complete song draft.';
  const response = await musicAI(prompt,'song');
  res.json({ok:true,response,structure:"Intro → Verse → Hook → Verse → Bridge → Final Hook",ts:new Date().toISOString()});
});

app.post('/api/music-command/chat', async (req,res)=>{
  const prompt = req.body?.prompt || req.body?.message || req.body?.input || '';
  const response = await musicAI(prompt,'chat');
  res.json({ok:true,response,ts:new Date().toISOString()});
});

app.get('/music-command',(req,res)=>res.redirect('/html/music-command/index.html'));
app.get('/music-command/app',(req,res)=>res.redirect('/html/music-command/app.html'));
app.get('/music-command/demo',(req,res)=>res.redirect('/html/music-command/demo-conductor.html'));
app.get('/music-command/how-to',(req,res)=>res.redirect('/html/music-command/how-to-guide.html'));
app.get('/music-command/presentation',(req,res)=>res.redirect('/html/music-command/presentation-live.html'));


// ======================================================
// MUSIC COMMAND SOLID ROUTES · RESTORED UI COMPAT
// ======================================================
const MUSIC_STATE = global.__TSM_MUSIC_STATE__ = global.__TSM_MUSIC_STATE__ || {
  dna:{adlibs:["yeah","let's go","uh"], tone:"motivational", style:"cadence-first"},
  history:[]
};

async function tsmMusicResponse(prompt, mode){
  try{
    if(!process.env.GROQ_API_KEY) throw new Error("missing key");

    const r = await fetch('https://api.groq.com/openai/v1/chat/completions',{
      method:'POST',
      headers:{
        'Authorization':`Bearer ${process.env.GROQ_API_KEY}`,
        'Content-Type':'application/json'
      },
      body:JSON.stringify({
        model:process.env.TSM_MODEL || 'llama-3.3-70b-versatile',
        messages:[
          {role:'system',content:'You are TSM Music Command. Never mention provider/model/API/key. Help create hooks, verses, bridges, ad-libs, song structure, and performance-ready polish.'},
          {role:'user',content:`Mode: ${mode || 'creative'}\n\n${prompt || ''}`}
        ],
        temperature:.65,
        max_tokens:1100
      })
    });

    if(!r.ok) throw new Error("AI unavailable");
    const data = await r.json();
    return data?.choices?.[0]?.message?.content || "";
  }catch(e){
    return `HOOK:
I keep rising when the pressure gets heavy
Turn the pain into power, now the whole room ready

BRIDGE:
I was down but I learned how to move with the weight
Now every scar got a sound and every loss got a place

AD-LIBS:
(yeah) (let's go) (uh) (from the ashes)

STRUCTURE:
Intro → Verse 1 → Pre-Hook → Hook → Verse 2 → Bridge → Final Hook → Outro

NEXT ACTION:
Tighten the hook, place ad-libs after impact lines, and make the bridge the emotional turning point.`;
  }
}

app.get('/music', (req,res)=>res.redirect('/html/music-command/index.html'));
app.get('/music/', (req,res)=>res.redirect('/html/music-command/index.html'));
app.get('/music/index', (req,res)=>res.redirect('/html/music-command/index.html'));
app.get('/music-command', (req,res)=>res.redirect('/html/music-command/index.html'));
app.get('/music-command/app', (req,res)=>res.redirect('/html/music-command/app.html'));
app.get('/music-command/demo', (req,res)=>res.redirect('/html/music-command/demo-conductor.html'));
app.get('/music-command/how-to', (req,res)=>res.redirect('/html/music-command/how-to-guide.html'));
app.get('/music-command/presentation', (req,res)=>res.redirect('/html/music-command/presentation-live.html'));



// ======================================================
// FINOPS STAFF ACCOUNTANT COPILOT
// Unified client-facing AP + AR + Tax + Compliance + Zero Trust + Strategist lane
// ======================================================
app.get('/finops/copilot',(req,res)=>res.redirect('/html/finops-suite/copilot.html'));

app.post('/api/finops/copilot', async (req,res)=>{
  const body=req.body||{};
  const workflow=body.workflow||'AP Aging';
  const workflows=body.workflows||[workflow,'Compliance Shield','Zero Trust','Strategist BNCA'];
  const context=body.context||'';

  // Server-side AI if available; safe fallback if not.
  async function ai(){
    if(!process.env.GROQ_API_KEY) throw new Error('missing key');
    const prompt=`You are TSM FinOps Staff Accountant Copilot.

Workflow: ${workflow}
Workflows chained: ${JSON.stringify(workflows)}
Context: ${context}

Return JSON only:
{
 "priority_rank":[{"rank":1,"lane":"...","issue":"...","impact":"...","owner":"...","status":"..."}],
 "combined_bnca":"...",
 "controller_note":"...",
 "business_outcome":"...",
 "confidence":0-100
}

Focus on AP, AR, bank reconciliation, month-end close, 1099/W-9 readiness, compliance support, zero-trust access risk, and controller-ready actions.`;

    const r=await fetch('https://api.groq.com/openai/v1/chat/completions',{
      method:'POST',
      headers:{'Authorization':`Bearer ${process.env.GROQ_API_KEY}`,'Content-Type':'application/json'},
      body:JSON.stringify({
        model:process.env.TSM_MODEL||'llama-3.3-70b-versatile',
        messages:[
          {role:'system',content:'You are TSM FinOps Staff Accountant Copilot. Never mention provider/model/API/key. Return JSON only.'},
          {role:'user',content:prompt}
        ],
        temperature:.24,
        max_tokens:1100
      })
    });
    if(!r.ok) throw new Error('ai unavailable');
    const data=await r.json();
    const text=data?.choices?.[0]?.message?.content||'';
    return JSON.parse(text.replace(/```json|```/g,'').trim());
  }

  try{
    const result=await ai();
    res.json({ok:true,workflow,workflows,...result,ts:new Date().toISOString()});
  }catch(e){
    res.json({
      ok:true,
      workflow,
      workflows,
      priority_rank:[
        {rank:1,lane:'AP',issue:'Vendor invoices need validation/support',impact:'Payment timing and close risk',owner:'Staff Accountant',status:'ACTION REQUIRED'},
        {rank:2,lane:'Reconciliation',issue:'Open reconciling items need documentation',impact:'Month-end close blocker',owner:'Staff Accountant / Controller',status:'WATCH'},
        {rank:3,lane:'Tax / 1099',issue:'Vendors need W-9 / threshold review',impact:'Filing window exposure',owner:'Tax Prep / Controller',status:'DUE BEFORE FILING'},
        {rank:4,lane:'Compliance / Zero Trust',issue:'Approval/support trail should be preserved',impact:'Audit readiness risk',owner:'Controller',status:'REVIEW'}
      ],
      combined_bnca:'Validate AP support first, resolve reconciliation gaps second, complete 1099/W-9 readiness third, then route the controller summary for close approval.',
      controller_note:'AP support and reconciliation gaps are the highest immediate blockers. Tax and compliance readiness should be reviewed in the same close cycle.',
      business_outcome:'Parallel FinOps apps converted into one staff-accountant workflow and controller-ready action plan.',
      confidence:89,
      ts:new Date().toISOString()
    });
  }
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`\n🚀 TSM Shell on http://0.0.0.0:${PORT}`);
  suites.forEach(s => console.log(`   ${s.route} → ${s.dir}/${s.index}`));
  console.log();
});

// Fallback: unmatched API requests

// ── PATCHED ROUTES ──────────────────────────────────────────────────────────

app.post('/api/hc/brief', async (req, res) => {
  const { agent='BEACON', context='', stakeholder='CFO', node='' } = req.body;
  const prompt = `You are ${agent}, a healthcare intelligence agent specializing in ${node || 'revenue cycle and payer compliance'}. Generate an executive brief for the ${stakeholder}. Context: ${context}. Return JSON: { ok:true, brief, key_findings, recommendations, risk_level, action_items }`;
  const result = await tsmAIJSON(prompt, { ok:false, response:'AI unavailable', ai_status:'fallback_no_mock_data_key_or_route_needed' });
  res.json(result);
});

app.post('/api/hc/layer2', async (req, res) => {
  const { node='', query='', context='' } = req.body;
  const prompt = `You are a Layer 2 healthcare mesh intelligence agent for the ${node} node. Deep-analyze: ${query}. Context: ${context}. Return JSON: { ok:true, analysis, signals, confidence, escalate, next_actions }`;
  const result = await tsmAIJSON(prompt, { ok:false, response:'AI unavailable', ai_status:'fallback_no_mock_data_key_or_route_needed' });
  res.json(result);
});

app.post('/api/hc/reports', async (req, res) => {
  const { type='summary', node='', period='current', context='' } = req.body;
  const prompt = `You are a healthcare reporting agent. Generate a ${type} report for the ${node} node covering ${period}. Context: ${context}. Return JSON: { ok:true, report_type, node, period, summary, metrics, trends, alerts }`;
  const result = await tsmAIJSON(prompt, { ok:false, response:'AI unavailable', ai_status:'fallback_no_mock_data_key_or_route_needed' });
  res.json(result);
});

app.post('/api/taxprep/v1', async (req, res) => {
  const { action='analyze', entity='', context='', fiscal_year='' } = req.body;
  const prompt = `You are HC Tax Prep agent. Action: ${action}. Entity: ${entity}. Fiscal year: ${fiscal_year}. Context: ${context}. Return JSON: { ok:true, action, entity, fiscal_year, analysis, deductions, compliance_flags, recommendations, estimated_liability }`;
  const result = await tsmAIJSON(prompt, { ok:false, response:'AI unavailable', ai_status:'fallback_no_mock_data_key_or_route_needed' });
  res.json(result);
});

app.post('/api/groq', async (req, res) => {
  const { prompt='', system='You are a healthcare AI assistant.', context='' } = req.body;
  const full = context ? `${context}\n\n${prompt}` : prompt;
  const result = await tsmAIJSON(`${system}\n\n${full}`, { ok:false, response:'AI unavailable', ai_status:'fallback_no_mock_data_key_or_route_needed' });
  res.json({ ok:true, response: result.narrative || result.response || JSON.stringify(result) });
});


// ── MISSING ROUTES PATCH ──────────────────────────────────────────────────

app.get('/api/music/activity', (_req, res) => {
  res.json({ ok: true, activity: MUSIC_STATE.activity || [] });
});

app.get('/api/music/platform', (_req, res) => {
  res.json({ ok: true, platform: { tier: 'pro', monetized: true, revenue: 0, streams: 0 } });
});

app.get('/api/music/engine', (_req, res) => {
  res.json({ ok: true, engine: { version: '2.0', agents: ['ZAY','DJ'], status: 'online' } });
});

app.get('/api/music/revision/state', (_req, res) => {
  res.json({ ok: true, revisions: MUSIC_STATE.revisions || [], current: MUSIC_STATE.currentRevision || null });
});

app.post('/api/music/song/learn', (req, res) => {
  const { song, lyrics, style } = req.body || {};
  if (!MUSIC_STATE.learnedSongs) MUSIC_STATE.learnedSongs = [];
  MUSIC_STATE.learnedSongs.push({ song, lyrics, style, ts: Date.now() });
  res.json({ ok: true, learned: MUSIC_STATE.learnedSongs.length });
});

app.post('/api/music/dna/learn', async (req, res) => {
  const { lyrics, style, artist } = req.body || {};
  if (!MUSIC_STATE.dna) MUSIC_STATE.dna = {};
  MUSIC_STATE.dna.learnedFrom = artist || 'unknown';
  MUSIC_STATE.dna.style = style || MUSIC_STATE.dna.style;
  res.json({ ok: true, dna: MUSIC_STATE.dna });
});

// ── END MISSING ROUTES PATCH ──────────────────────────────────────────────




// ── AI COACH ROUTE ────────────────────────────────────────────────────────────
app.post('/api/music/coach', async (req, res) => {
  const { tab = 'draft', lyrics = '', dna = {}, request = '' } = req.body || {};
  const hasLyrics = lyrics.trim().length > 20;

  const stepGuides = {
    draft: {
      headline: 'Score and strengthen your draft',
      features: `FIELDS: "Your Lyrics / Hook / Verse / Draft" textarea (draft-input), "Focused Request" textarea (tell the agent exactly what you want), Agent selector, Priority selector.
BUTTONS: "Run Agent Pass" (scores cadence, emotion, structure, imagery), "Load Demo Draft" (loads example), "Clear" (resets), "Save to Bank" (after output), "Copy", "Send to Revision Mode".
METRICS shown after analysis: Hook Identity, Cadence Control, Lexical Sharpness, Structure Health, DNA Match.
WORKFLOW: Paste lyrics → write focused request → pick agent → Run Agent Pass → read metrics → Iterate Again → Save to Bank or Send to Revision.`,
      focus: 'lyric quality, cadence scoring, hook identity, and focused requests to the agent'
    },
    revision: {
      headline: 'Revise with surgical precision',
      features: `FIELDS: Box 1 "Current Draft" (what you want revised), Box 2 "Edit Instructions" (what should change — e.g. add pre-hook, tighten syllables, make darker), Box 3 "Protect" (lines that must not change), Box 4 "Output Options" (3 variant styles you want back), Agent selector, Output Format selector.
BUTTONS: "Run Revision Mode" (sends all 4 boxes to agent), "Load Example" (demo content), "Save to Bank", "Copy".
WORKFLOW: Fill Box 1 with draft → Box 2 with specific edits → Box 3 with protected lines → Box 4 with 3 output styles → Run Revision Mode → pick strongest option → Save to Bank.`,
      focus: 'precise edit instructions, protecting key lines, and generating multiple revision options'
    },
    generate: {
      headline: 'Generate new sections from your DNA',
      features: `FIELDS: "What to Generate" selector (Hook, Bridge, Ad-libs, Song Structure, Verse, Outro), "Tone/Feel" selector (Triumphant, Melancholy, Hype, etc.), "Your Concept/Starting Point" textarea, "Reference Lines" textarea (optional — paste lines to match your style).
BUTTONS: "Generate Hook" (3 hook variants from DNA), "Build Bridge" (emotional pivot section), "Place Ad-Libs" (adds signature vocal punctuation at impact points), "Song Structure" (maps full Verse/Hook/Bridge layout).
WORKFLOW: Pick what to generate → set tone → describe concept → add reference lines → click the matching button → pick strongest output.`,
      focus: 'concept clarity, tone selection, and using reference lines to match artist style'
    },
    songbank: {
      headline: 'Manage and learn from your catalog',
      features: `BUTTONS: "Save to Bank" (from Draft or Revision output), "Load" (reloads any saved song into Draft panel), "Learn from Song" (feeds song into Artist DNA), "Export TXT" (packages for DAW or notes app).
WORKFLOW: Songs auto-save via Save to Bank → browse catalog → Load any song to keep refining → Learn from Song to update your DNA → Export TXT when ready for DAW.`,
      focus: 'catalog organization, DNA learning from past songs, and export workflow'
    },
    dna: {
      headline: 'Lock in your artist signature',
      features: `FIELDS: Ad-libs list (edit your signature phrases — yeah, let's go, uh, ay), Style/Tone selector, Vocab terms.
BUTTONS: "Learn from Lyrics" (extracts patterns from pasted lyrics), "Save DNA" (locks current profile), "Reset".
DNA AFFECTS: Every agent pass, every hook generated, every ad-lib placement uses your DNA profile.
WORKFLOW: Edit your ad-libs → set your tone → paste lyrics and hit Learn from Lyrics → Save DNA → all future generations match your style.`,
      focus: 'signature ad-libs, tone consistency, and training DNA from existing lyrics'
    },
    studio: {
      headline: 'Polish, export, and monetize',
      features: `BUTTONS: "Generate 10 Hooks" (batch hook variants for A/B testing), "Export TXT" (full song packaged for DAW), "Save Artist Session" (saves entire workspace state), monetization tier buttons.
COMMERCE STATE: Shows monetized status, revenue tier (Pro), stream count.
WORKFLOW: Finalize lyrics in Draft → Generate 10 Hooks for A/B testing → Export TXT for DAW → Save Artist Session to preserve workspace → set monetization tier.`,
      focus: 'export readiness, batch generation, session saving, and monetization setup'
    }
  };

  const guide = stepGuides[tab] || stepGuides.draft;

  const prompt = `You are TSM AI Coach inside the TSM Music Command Center app.

CURRENT PANEL: ${tab.toUpperCase()}
USER HAS LYRICS: ${hasLyrics ? 'YES: "' + lyrics.slice(0, 300) + '"' : 'NO — fields are empty'}
ARTIST DNA: ${JSON.stringify(dna)}
USER QUESTION: ${request || 'Guide me through this panel step by step'}

EXACT FEATURES IN THIS PANEL:
${guide.features}

YOUR RULES:
- Reference ONLY the actual buttons, fields, and selectors listed above — use their exact names
- Be direct and specific — tell them exactly what to click or type right now
- If they have lyrics, give ONE concrete line-level rewrite example (before → after)
- If fields are empty, tell them exactly what to paste/type first
- Keep coaching under 3 sentences
- Quick tips must reference actual button/field names from this panel
- Next Step must name a specific button to click

Return ONLY valid JSON, no markdown, no explanation:
{
  "headline": "8 words max, action-oriented",
  "coaching": "2-3 sentences, specific to their current state",
  "example_before": "only if they have lyrics, else empty string",
  "example_after": "only if they have lyrics, else empty string",
  "quick_tips": ["tip referencing actual button/field", "tip referencing actual button/field", "tip referencing actual button/field"],
  "next_step": "Name the exact button to click or field to fill right now",
  "score": {"overall": 0, "flow": 0, "hooks": 0, "imagery": 0}
}`;

  try {
    const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.GROQ_API_KEY}`
      },
      body: JSON.stringify({
        model: process.env.TSM_MODEL || 'llama-3.3-70b-versatile',
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 700,
        temperature: 0.6
      })
    });
    const d = await r.json();
    console.log('[COACH GROQ]', JSON.stringify(d).slice(0,500));
    const text = d.choices?.[0]?.message?.content || '{}';
    let parsed = {};
    try {
      parsed = JSON.parse(text.replace(/```json|```/g, '').trim());
    } catch {
      parsed = {
        headline: guide.headline,
        coaching: `You are in the ${tab} panel. ${guide.features.split('\n')[0]}`,
        quick_tips: guide.features.split('\n').filter(l => l.includes(':')).slice(0,3).map(l => l.trim()),
        next_step: hasLyrics ? 'Click Run Agent Pass to score your lyrics' : 'Paste your lyrics to get started'
      };
    }
    res.json({ ok: true, tab, ...parsed });
  } catch(e) {
    console.error('[COACH ERROR]', e.message, e.stack);
    res.json({
      ok: false, tab,
      error: e.message,
      headline: guide.headline,
      coaching: guide.features.split('\n')[0],
      quick_tips: ['Fill all fields before running', 'Use Load Example to see expected input', 'Save to Bank after every strong output'],
      next_step: hasLyrics ? 'Click Run Agent Pass' : 'Paste your lyrics first'
    });
  }
});

app.get('/api/config', (_req, res) => {
  res.json({ ok:true, model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', nodes:15, suite:'healthcare', ai:!!process.env.GROQ_API_KEY, version:'2.0.0' });
});

app.post('/api/chat', async (req, res) => {
  const { message='', node='', agent='HC Assistant', history=[] } = req.body;
  const historyText = history.slice(-6).map(m => `${m.role}: ${m.content}`).join('\n');
  const prompt = `You are ${agent}${node ? `, the ${node} specialist` : ''} in the TSM Healthcare Suite.\n${historyText ? `Conversation so far:\n${historyText}\n\n` : ''}User: ${message}\nReturn JSON: { ok:true, response, agent, suggestions }`;
  const result = await tsmAIJSON(prompt, { ok:false, response:'AI unavailable', ai_status:'fallback_no_mock_data_key_or_route_needed' });
  res.json(result);
});


// CONSTRUCTION SUITE
app['post']('/api/construction/query', async (req, res) => {
  const { action='', agent='FORGE', payload={} } = req.body;
  const { context='', stakeholder='Project Manager', node='', priority='NORMAL' } = payload;
  const personas = {'construction-command':'Construction Command Center specialist','construction-strategist':'Construction Strategist for planning','construction-pro':'Construction Pro for on-site execution','compliance':'Construction Compliance officer','financial':'Construction Financial analyst','legal':'Construction Legal counsel','zero-trust':'Construction Zero-Trust security architect','construct-presentation':'Construction Presentation specialist'};
  const persona = personas[node] || 'Construction intelligence agent';
  const prompt = 'You are ' + agent + ', a ' + persona + ' in the TSM Construction Suite. Action: ' + action + '. Stakeholder: ' + stakeholder + '. Priority: ' + priority + '. Context: ' + context + '. Return ONLY valid JSON: {"ok":true,"action":"' + action + '","agent":"' + agent + '","node":"' + node + '","response":"...","key_findings":[],"recommendations":[],"risk_level":"MEDIUM","next_steps":[]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:900, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});

// FINOPS SUITE
app['post']('/api/financial/query', async (req, res) => {
  const { action='', agent='FINOPS', payload={} } = req.body;
  const { context='', stakeholder='CFO', node='', priority='NORMAL' } = payload;
  const prompt = 'You are ' + agent + ', a FinOps intelligence agent for the ' + (node||'financial') + ' module. Action: ' + action + '. Stakeholder: ' + stakeholder + '. Priority: ' + priority + '. Context: ' + context + '. Return ONLY valid JSON: {"ok":true,"action":"' + action + '","agent":"' + agent + '","node":"' + node + '","response":"...","metrics":{},"recommendations":[],"risk_level":"MEDIUM","next_steps":[]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:1000, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/finops/report', async (req, res) => {
  const { type='summary', context='', period='current', node='' } = req.body;
  const prompt = 'You are a FinOps reporting agent. Generate a ' + type + ' report for ' + (node||'organization') + ' covering ' + period + '. Context: ' + context + '. Return ONLY valid JSON: {"ok":true,"type":"' + type + '","period":"' + period + '","summary":"...","revenue":0,"expenses":0,"net":0,"variance_pct":0,"alerts":[],"recommendations":[]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:1000, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/finops/actions', async (req, res) => {
  const { context='', priority='NORMAL', module='' } = req.body;
  const prompt = 'You are a FinOps action agent for the ' + (module||'finance') + ' module. Priority: ' + priority + '. Context: ' + context + '. Return ONLY valid JSON: {"ok":true,"module":"' + module + '","actions":[],"quick_wins":[],"risk_flags":[],"next_review":"weekly"}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:900, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/finops/upload-doc', async (req, res) => {
  const { filename='', content='', type='financial' } = req.body;
  const prompt = 'Analyze this ' + type + ' document: ' + filename + '. Content: ' + content.slice(0,2000) + '. Return ONLY valid JSON: {"ok":true,"filename":"' + filename + '","type":"' + type + '","summary":"...","key_figures":{},"flags":[],"action_items":[]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:1000, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/finops/run-doc', async (req, res) => {
  const { doc='', action='analyze', context='' } = req.body;
  const prompt = 'Run action: ' + action + ' on document: ' + doc + '. Context: ' + context + '. Return ONLY valid JSON: {"ok":true,"doc":"' + doc + '","action":"' + action + '","result":"...","extracted":{},"next_steps":[]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:900, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});

// MUSIC SUITE — missing routes

// safeParseGroq — extracts valid JSON, handles rate limits, newlines, and truncation
function safeParseGroq(text, fallback = {}) {
  try {
    const clean = text.replace(/```json|```/g, '').trim();
    return JSON.parse(clean);
  } catch(_) {
    try {
      // extract largest {...} block and clean it
      const start = text.indexOf('{');
      const end = text.lastIndexOf('}');
      if (start !== -1 && end !== -1 && end > start) {
        const block = text.slice(start, end + 1);
        // replace literal newlines with \n so JSON.parse accepts them
        const safe = block.replace(/\r?\n/g, '\\n').replace(/\t/g, '\\t');
        return JSON.parse(safe);
      }
    } catch(_) {}
    return { ok: false, error: 'parse_failed', raw: text.slice(0, 200), ...fallback };
  }
}

// groqFetch — wraps Groq API call with rate limit detection
async function groqFetch(prompt, maxTokens = 900) {
  const model = process.env.TSM_MODEL || 'llama-3.1-8b-instant';
  const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + process.env.GROQ_API_KEY
    },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }]
    })
  });
  const raw = await r.json();
  if (raw.error?.code === 'rate_limit_exceeded') {
    const msg = raw.error.message || '';
    const match = msg.match(/try again in ([\d\.]+[smh])/i);
    throw new Error('RATE_LIMITED:' + (match ? match[1] : '60s'));
  }
  const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g, '').trim();
  return text;
}
app['get']('/api/music/billing/state', (req, res) => res.json({ ok:true, tier:'pro', status:'active', features:['unlimited_revisions','agent_chain','dna_learning','export'], usage:{ revisions:0, sessions:0 } }));
app['post']('/api/music/billing/upgrade-intent', (req, res) => { const { tier='pro' } = req.body; res.json({ ok:true, tier, intent:'captured', next:'checkout', message:'Upgrade intent recorded' }); });
app['post']('/api/music/billing/set-tier-dev', (req, res) => { const { tier='pro' } = req.body; res.json({ ok:true, tier, message:'Dev tier set to ' + tier }); });
app['get']('/api/music/monetization/state', (req, res) => res.json({ ok:true, monetized:true, tier:'pro', revenue:0, streams:0, splits:[] }));
app['get']('/api/music/activity', (req, res) => res.json({ ok:true, activity:[], recent_sessions:[], last_active: new Date().toISOString() }));
app['get']('/api/music/revision/state', (req, res) => res.json({ ok:true, revision:null, history:[], score:75, status:'ready' }));
app['post']('/api/music/revision/select', (req, res) => { const { revision_id='' } = req.body; res.json({ ok:true, selected: revision_id, status:'selected' }); });
app['post']('/api/music/revision/pick-rerun', async (req, res) => {
  const { lyrics='', agent='ZAY', style='' } = req.body;
  const prompt = 'You are ' + agent + ', a music revision agent. Re-run revision on these lyrics with style: ' + style + '. Lyrics: ' + lyrics + '. Return ONLY valid JSON: {"ok":true,"agent":"' + agent + '","revised":"...","cadence":80,"emotion":80,"structure":80,"imagery":80,"decision":"Improved"}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:1000, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/music/revision/generate', async (req, res) => {
  const { lyrics='', style='', mood='', genre='' } = req.body;
  const prompt = 'You are a music AI. Generate a revision of these lyrics. Style: ' + style + '. Mood: ' + mood + '. Genre: ' + genre + '. Original: ' + lyrics + '. Return ONLY valid JSON: {"ok":true,"revised":"...","changes":[],"score":80,"emotion":80,"structure":80}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:1000, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/music/agent/run', async (req, res) => {
  const { agent='RIYA', task='', lyrics='', context='' } = req.body;
  const prompt = 'You are ' + agent + ', a professional music AI agent. Task: ' + task + '. Context: ' + context + '. Lyrics: ' + lyrics + '. Return ONLY valid JSON: {"ok":true,"agent":"' + agent + '","output":"...","score_delta":5,"decision":"Approved","ad_libs":[]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:700, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/music/agent/chain', async (req, res) => {
  const { agents=['RIYA','ZAY'], lyrics='', task='', rounds=1 } = req.body;
  const prompt = 'You are a music agent chain coordinator running agents: ' + agents.join(', ') + '. Task: ' + task + '. Rounds: ' + rounds + '. Input lyrics: ' + lyrics + '. Return ONLY valid JSON: {"ok":true,"agents":' + JSON.stringify(agents) + ',"rounds_completed":' + rounds + ',"final_lyrics":"...","chain_log":[],"final_score":85}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:800, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['get']('/api/music/engine', async (req, res) => {
  const { action='', lyrics='', config='' } = req.query;
  const prompt = 'You are the TSM Music Engine. Action: ' + action + '. Config: ' + JSON.stringify(config) + '. Lyrics: ' + lyrics + '. Return ONLY valid JSON: {"ok":true,"action":"' + action + '","result":"...","metrics":{"energy":80,"flow":80,"impact":80},"suggestions":[]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:1000, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['get']('/api/music/evolution', async (req, res) => {
  const { lyrics='', generations=1, target='' } = req.query;
  if (!lyrics) return res.json({ ok:true, generations:1, evolved:'Provide lyrics to evolve', evolution_log:['Ready'], improvement_pct:0 });
  const prompt = 'Return ONLY a raw JSON object, no explanation, no markdown. Evolve these lyrics over ' + generations + ' generation(s). JSON format: {"ok":true,"generations":' + generations + ',"evolved":"improved lyrics here","evolution_log":["change 1","change 2"],"improvement_pct":15}. Lyrics to evolve: ' + lyrics;
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:700, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/music/export', (req, res) => {
  const { lyrics='', format='txt', metadata={} } = req.body;
  res.json({ ok:true, format, filename:'export-' + Date.now() + '.' + format, content: lyrics, metadata, exported_at: new Date().toISOString() });
});
app['post']('/api/music/hooks/generate10', async (req, res) => {
  const { theme='', genre='', mood='' } = req.body;
  const prompt = 'Generate 10 unique song hooks. Theme: ' + theme + '. Genre: ' + genre + '. Mood: ' + mood + '. Return ONLY valid JSON: {"ok":true,"hooks":["hook1","hook2","hook3","hook4","hook5","hook6","hook7","hook8","hook9","hook10"]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:900, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/music/platform', (req, res) => {
  const { action='status' } = req.body;
  res.json({ ok:true, action, platform:'TSM Music Command', version:'2.0', status:'active', agents:['RIYA','ZAY','NOVA','ECHO'], features:['agent_chain','dna_learning','evolution','hooks'] });
});
app['post']('/api/music/dashboard-sync', (req, res) => {
  res.json({ ok:true, synced:true, ts: new Date().toISOString(), state:{ sessions:0, revisions:0, score:75, agents_active:4 } });
});
app['post']('/api/music/session/save', (req, res) => {
  const { session={} } = req.body;
  res.json({ ok:true, saved:true, session_id:'sess-' + Date.now(), ts: new Date().toISOString() });
});
app['post']('/api/music/song/learn', async (req, res) => {
  const { lyrics='', feedback='', style='' } = req.body;
  const prompt = 'You are a music learning AI. Learn from this song feedback. Lyrics: ' + lyrics + '. Feedback: ' + feedback + '. Style: ' + style + '. Return ONLY valid JSON: {"ok":true,"learned":true,"patterns":[],"style_profile":{},"next_suggestions":[]}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:900, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['post']('/api/music/dna/learn', async (req, res) => {
  const { lyrics='', artist='', style='', feedback='' } = req.body;
  const prompt = 'You are the TSM Music DNA learning engine. Analyze and learn from: artist=' + artist + ' style=' + style + ' feedback=' + feedback + ' lyrics=' + lyrics + '. Return ONLY valid JSON: {"ok":true,"dna_updated":true,"artist":"' + artist + '","learned_patterns":[],"style_vector":{},"confidence":0.85}';
  try { const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer ' + process.env.GROQ_API_KEY}, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', max_tokens:900, messages:[{role:'user',content:prompt}] }) }); const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/```json|```/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) {
      return res.status(429).json({ ok:false, error:'rate_limited', retry_after: e.message.split(':')[1], message:'AI quota reached. Try again in ' + e.message.split(':')[1] });
    }
    return res.json({ ok:false, error: e.message });
  }
});
app['get']('/api/music/demo/validate', (req, res) => { const { demo_token='' } = req.query; res.json({ ok:true, valid:true, demo_token, expires_at: new Date(Date.now()+3600000).toISOString(), features:['revision','agent_pass','structure'] }); });
app['post']('/api/music/demo/view', (req, res) => { const { demo_token='' } = req.body?.demo_token ? req.body : req.query; res.json({ ok:true, demo_token, lyrics:'', session:{}, created_at: new Date().toISOString() }); });
app['post']('/api/music/demo/create', (req, res) => { res.json({ ok:true, demo_token:'demo-' + Date.now(), expires_at: new Date(Date.now()+3600000).toISOString(), share_url: 'https://tsm-shell.fly.dev/music-command/demo?demo_token=demo-' + Date.now() }); });


// MUSIC COACH — full step-by-step AI guidance
// CATCH-ALLS — must be last

// ── Generic LLM route for frontend callClaude() ───────────────────────────────
app.post('/api/music/llm', async (req, res) => {
  try {
    const { system = '', user = '' } = req.body;
    if (!user) return res.status(400).json({ ok: false, error: 'Missing user prompt' });
    const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.GROQ_API_KEY}`
      },
      body: JSON.stringify({
        model: process.env.TSM_MODEL || 'llama-3.3-70b-versatile',
        max_tokens: 1200,
        temperature: 0.7,
        messages: [
          ...(system ? [{ role: 'system', content: system }] : []),
          { role: 'user', content: user }
        ]
      })
    });
    const d = await r.json();
    const text = d.choices?.[0]?.message?.content || '';
    if (!text) {
      console.error('[LLM] Empty:', JSON.stringify(d).slice(0,200));
      return res.status(502).json({ ok: false, error: 'Empty LLM response' });
    }
    res.json({ ok: true, text });
  } catch(e) {
    console.error('[LLM] Error:', e.message);
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.post("/api/music/agent-pass-v2", async (req, res) => {
  const prompt = req.body?.prompt || req.body?.message || req.body?.input || "";
  const result = await tsmAIJSON(`You are TSM Music Command. You MUST return EXACTLY 3 options in this JSON. Do not return fewer. All 3 must have different lyrics: {"options":[{"label":"Option 1: [short descriptor]","text":"lyrics here"},{"label":"Option 2: [short descriptor]","text":"lyrics here"},{"label":"Option 3: [short descriptor]","text":"lyrics here"}],"hook_score":85,"cadence_score":88,"lex_score":82} Task: ${prompt} Keep lyrics raw, authentic, street. No explanation outside JSON.`, {options:[{label:"Option 1",text:prompt},{label:"Option 2",text:prompt},{label:"Option 3",text:prompt}],hook_score:75,cadence_score:75,lex_score:75});
  res.json({ok:true, ...result, output: result.options?.[0]?.text || ""});
});
app.post("/api/music/export/save", async (req, res) => {
  const { content, filename } = req.body || {};
  if (!content) return res.status(400).json({ ok: false, error: "No content" });
  const fs = require("fs");
  const path = require("path");
  const dir = path.join(__dirname, "exports");
  if (!fs.existsSync(dir)) fs.mkdirSync(dir);
  const fname = filename || "TSM_Export_" + Date.now() + ".txt";
  fs.writeFileSync(path.join(dir, fname), content);
  res.json({ ok: true, url: "/exports/" + fname, filename: fname });
});
app.use('/exports', require('express').static(require('path').join(__dirname, 'exports')));
app.use('/api', (req, res) => res.status(404).json({ ok:false, error:'API route not found', path:req.path }));
app.use((req, res) => res.status(404).send('<pre>404 Not found: ' + req.path + '</pre>'));
