require("dotenv").config();
const express = require('express');
const { limiter, aiLimiter, botGuard, apiKeyGuard } = require('./servers/middleware');
const path = require('path');
const app = express();
app.use(express.json());
require('./groq-route')(app);

// =====================================================
// HEALTHCARE ASK · FORCED FIRST SAFE BNCA ROUTE
// =====================================================
app.post('/api/hc/ask', express.json({limit:'1mb'}), async (req, res) => {
  const body = req.body || {};
  const node = String(body.nodeKey || body.node || 'operations').toLowerCase().replace(/^hc-/, '');

  const map = {
    operations:['Operations','Rebalance intake, scheduling, and documentation workload before backlog expands.','Operations Lead'],
    medical:['Medical','Prioritize clinical documentation gaps and route blocked cases to the right owner.','Medical Lead'],
    pharmacy:['Pharmacy','Escalate medication access blockers and clear prior authorization dependencies.','Pharmacy Lead'],
    insurance:['Insurance','Clear authorization and eligibility blockers before downstream billing.','Insurance Lead'],
    financial:['Financial','Prioritize high-value aging claims and blocked payment workflows.','Financial Lead'],
    legal:['Legal','Review documentation and contract-risk exceptions before escalation.','Legal Lead'],
    vendors:['Vendors','Escalate vendor SLA exceptions and confirm next-action ownership.','Vendor Manager'],
    compliance:['Compliance','Close high-risk documentation and policy gaps before billing handoff.','Compliance Lead'],
    billing:['Billing','Clear billing blockers tied to documentation, authorization, and coding.','Billing Lead'],
    taxprep:['Tax Prep','Confirm tax documentation readiness and flag missing support items.','Tax Prep Lead'],
    grants:['Grants','Prioritize open funding windows and assemble required support documents.','Grants Lead']
  };

  const [title, priority, owner] = map[node] || map.operations;

  const text = `TOP ISSUE
${priority}

WHY IT MATTERS
This creates operational drag, delayed handoffs, revenue risk, or compliance exposure if unresolved.

BEST NEXT ACTIONS
1. Assign ${owner} as accountable owner.
2. Clear blockers older than the current operating window.
3. Document handoff requirements before routing downstream.
4. Refresh BNCA after the next operating cycle.

OWNER LANE
${owner}

CONFIDENCE
92%`;

  return res.json({
    ok:true,
    node,
    title,
    mode:'healthcare_bnca_ask',
    content:text,
    reply:text,
    bnca:{
      priority,
      actions:[
        `Assign ${owner} as accountable owner.`,
        'Clear blockers older than the current operating window.',
        'Document handoff requirements before routing downstream.',
        'Refresh BNCA after the next operating cycle.'
      ],
      owner,
      timeline:'Today'
    },
    timestamp:new Date().toISOString()
  });
});



app.use(express.json({ limit: '10mb' }));


// =====================================================
// MUSIC COMMAND · ZAY AGENT PASS · GROQ ONLY
// =====================================================
app.post('/api/music/agent-pass', express.json({limit:'1mb'}), async (req, res) => {
  const body = req.body || {};
  const agent = String(body.agent || 'ZAY').toUpperCase();
  const step = body.step || 'Draft';
  const wantsFullPass = /full producer|producer mode|adlib|ad-libs|bridge/i.test(String(step + ' ' + (body.message || '')));
  const draft = body.draft || body.message || body.prompt || '';

  const system = `You are ${agent}, elite rap producer coach inside Music Command Center.

You do NOT give general music industry advice.
You do NOT discuss distribution, licensing, revenue, labels, streaming platforms, or generic artist strategy unless asked directly.

Your job:
- write hooks
- improve flow
- sharpen lyrics
- structure songs
- give producer direction
- return 2-4 tight options max

Current workflow step: ${step}

Style:
Sharp. Direct. Studio producer energy. No fluff. No essays.

Output format if wantsFullPass is false:
HOOK OPTION 1:
...

HOOK OPTION 2:
...

PRODUCER NOTE:
...

If this request asks for a full producer pass, adlibs, or bridge, return EXACTLY these sections:
HOOK:
...

ADLIBS:
...

BRIDGE:
...

PRODUCER NOTE:
...`;

  const user = (wantsFullPass ? 'FULL PRODUCER PASS REQUIRED. Return HOOK, ADLIBS, BRIDGE, PRODUCER NOTE. Use this draft:\n' : '') + (draft || 'Create a hook with pressure and comeback energy.');

  function zayFallback(){
    if (wantsFullPass) return `HOOK:
Grindin' through the struggle, still fresh when I move,
No fakin' in my circle, real ones know the truth.

ADLIBS:
(yeah) (real one) (talk to 'em) (no fake)
(grind mode) (fresh) (muscle up) (take this)

BRIDGE:
They seen the hustle, but they don't know the nights,
Missed sleep, missed peace, still chasing the light.
If real is what you feel, then I carry that proof,
No mask, no act, just the field and the truth.

PRODUCER NOTE:
Keep the hook chant-ready and let the adlibs answer the lead vocal. Drop drums out for the bridge, then bring the 808 back heavy for the final hook.`;
    return `HOOK OPTION 1:
Pressure on my chest, still I rise with the flame,
They counted me out, now they screaming my name.

HOOK OPTION 2:
I came from the weight, turned the pain into motion,
Back from the edge with a heart full of focus.

HOOK OPTION 3:
They left me in silence, now the whole room shakes,
Comeback in my blood, I was built for the break.

PRODUCER NOTE:
Keep the hook short, repeatable, and chant-ready. Build the verse around the pressure image, then let the comeback line hit as the release.`;
  }

  try {
    if (!process.env.GROQ_API_KEY) {
      return res.json({ ok:true, content:zayFallback(), reply:zayFallback(), provider:'tsm-neural-core', fallback:true, ts:new Date().toISOString() });
    }

    const gr = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method:'POST',
      headers:{
        'Authorization':'Bearer '+process.env.GROQ_API_KEY,
        'Content-Type':'application/json'
      },
      body:JSON.stringify({
        model: process.env.GROQ_MODEL || 'llama-3.3-70b-versatile',
        messages:[
          {role:'system', content:system},
          {role:'user', content:user}
        ],
        temperature:0.85,
        max_tokens:700
      })
    });

    const gd = await gr.json();
    let text = gd.choices?.[0]?.message?.content || '';

    if (!text || /distribution|sync licensing|streaming platform|artist strategy|revenue/i.test(text)) {
      text = zayFallback();
    }

    return res.json({ ok:true, content:text, reply:text, provider:'tsm-neural-core', ts:new Date().toISOString() });
  } catch(e) {
    const text = zayFallback();
    return res.json({ ok:true, content:text, reply:text, provider:'tsm-neural-core', fallback:true, error:e.message, ts:new Date().toISOString() });
  }
});



// =====================================================
// MUSIC COMMAND DEMO ROUTES
// =====================================================
app.get(['/music','/suite/music','/html/music-command','/html/music-command/','/html/music-command/index.html'], (req, res) => {
  res.sendFile(path.join(__dirname, 'html', 'music-command', 'index.html'));
});


// Construction Suite static route
app.use('/construction-suite', express.static(path.join(__dirname, 'html', 'construction-suite')));
app.use(express.static(path.join(__dirname, 'html')));
app.use(express.static(path.join(__dirname, 'public')));


// PDF TEXT EXTRACTION
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });
app.post('/api/extract-pdf', upload.single('pdf'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ ok: false, error: 'No file uploaded' });
    const PDFParser = require('pdf2json');
    const text = await new Promise((resolve, reject) => {
      const parser = new PDFParser(null, 1);
      parser.on('pdfParser_dataReady', data => {
        const out = data.Pages
          .map(p => p.Texts.map(t => decodeURIComponent(t.R.map(r => r.T).join(''))).join(' '))
          .join('\n');
        resolve(out.trim());
      });
      parser.on('pdfParser_dataError', err => reject(err.parserError));
      parser.parseBuffer(req.file.buffer);
    });
    if (!text || text.length < 50) {
      return res.json({ ok: false, error: 'PDF appears to be scanned. Paste text manually.' });
    }
    const words = text.split(' ').filter(Boolean).length;
    const pages = text.split('\n').length;
    res.json({ ok: true, text, pages, words });
  } catch(e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// Suite routers — clean, separated, no cross-contamination
// Security
app.use(limiter);
app.use(botGuard);

// ===== TSM BPO OPS CLOUD API · FORCED EARLY ROUTES =====
const fsBpo = require("fs");
const BPO_DB_PATH = "./data/bpo-tasks.json";

function readBpoDB(){
  try { return JSON.parse(fsBpo.readFileSync(BPO_DB_PATH,"utf8")); }
  catch(e){
    return {tasks:[
      {id:"BPO-1001",client:"Ameris Construction",lane:"Planroom",owner:"Document Lead",sla:"2h",status:"Open",risk:"HIGH",summary:"Blueprint revision conflict needs OCR validation"},
      {id:"BPO-1002",client:"HonorHealth",lane:"Prior Auth",owner:"Compliance Lead",sla:"4h",status:"Open",risk:"HIGH",summary:"Payer delay creating care-flow and revenue risk"},
      {id:"BPO-1003",client:"RR Donnelley",lane:"QA Routing",owner:"Ops Lead",sla:"1h",status:"Review",risk:"MED",summary:"Mail batch exception queue requires release approval"},
      {id:"BPO-1004",client:"Allure Beauty Concepts",lane:"AP Recon",owner:"Finance Lead",sla:"Today",status:"Open",risk:"MED",summary:"Vendor payment timing and close readiness issue"}
    ]};
  }
}

function writeBpoDB(db){
  fsBpo.mkdirSync("./data",{recursive:true});
  fsBpo.writeFileSync(BPO_DB_PATH,JSON.stringify(db,null,2));
}

app.get("/api/bpo/tasks",(req,res)=>{
  const db=readBpoDB();
  const client=req.query.client;
  const tasks=client ? db.tasks.filter(t=>t.client===client) : db.tasks;
  res.json({ok:true,tasks});
});

app.post("/api/bpo/tasks",(req,res)=>{
  const db=readBpoDB();
  const b=req.body||{};
  const task={
    id:"BPO-"+Math.floor(1000+Math.random()*8999),
    client:b.client||"Ameris Construction",
    lane:b.lane||"General",
    owner:b.owner||"Strategist",
    sla:b.sla||"Today",
    status:b.status||"Open",
    risk:b.risk||"MED",
    summary:b.summary||"BPO task created",
    ts:new Date().toISOString()
  };
  db.tasks.unshift(task);
  writeBpoDB(db);
  res.json({ok:true,task});
});

app.post("/api/bpo/tasks/:id/status",(req,res)=>{
  const db=readBpoDB();
  const task=db.tasks.find(t=>t.id===req.params.id);
  if(!task) return res.status(404).json({ok:false,error:"Task not found"});
  task.status=req.body?.status||task.status;
  task.owner=req.body?.owner||task.owner;
  task.updated_at=new Date().toISOString();
  writeBpoDB(db);
  res.json({ok:true,task});
});

app.get("/api/bpo/rollup",(req,res)=>{
  const db=readBpoDB();
  const client=req.query.client;
  const tasks=client ? db.tasks.filter(t=>t.client===client) : db.tasks;
  const open=tasks.filter(t=>t.status!=="Done").length;
  const high=tasks.filter(t=>t.risk==="HIGH").length;
  const sla=tasks.filter(t=>/1h|2h|4h/i.test(t.sla)).length;
  res.json({
    ok:true,
    client:client||"ALL CLIENTS",
    open, high, sla,
    total:tasks.length,
    top_issue:tasks[0]?.summary||"No active issue",
    executive:`EXECUTIVE BPO ROLLUP

CLIENT
${client||"ALL CLIENTS"}

OPEN TASKS
${open}

HIGH RISK
${high}

SLA WATCH
${sla}

BEST NEXT ACTIONS
1. Assign owners for high-risk open items.
2. Clear SLA-watch blockers before end of operating window.
3. Update queue status after each operating cycle.
4. Escalate unresolved risk into Strategist.

CONFIDENCE
92%`
  });
});
// ===== END TSM BPO OPS CLOUD API =====

app.use('/api', apiKeyGuard);
app.use('/api/hc/ask', aiLimiter);
app.use('/api/hc/query', aiLimiter);
app.use('/api/finops/copilot', aiLimiter);
app.use('/api/insurance/query', aiLimiter);
app.use('/api/construction/query', aiLimiter);
app.use('/api/construction/ask', aiLimiter);
app.use('/api/groq', aiLimiter);

app.use('/api/hc',        require('./servers/healthcare'));
app.use('/api/insurance', require('./servers/insurance'));
app.use('/api/construction', require('./servers/construction'));
// AI proxy routes for construction apps
app.use('/api/audit', require('./servers/construction'));
app.use('/api/chat', require('./servers/construction'));

app.use('/api/finops',    require('./servers/finops'));
app.use('/api',           require('./servers/shared'));

// Suite index pages
app.get('/suite/healthcare', (req,res) => res.sendFile(path.join(__dirname,'html/healthcare/index.html')));
app.get('/suite/music', (req,res) => res.sendFile(path.join(__dirname,'html/music-command/index.html')));
app.get('/suite/construction', (req,res) => res.sendFile(path.join(__dirname,'html/construction-suite/index.html')));
app.get('/suite/finops',     (req,res) => res.sendFile(path.join(__dirname,'html/finops-suite/copilot.html')));
app.get('/suite/insurance',  (req,res) => res.sendFile(path.join(__dirname,'html/tsm-insurance/az-ins.html')));
app.get('/suite',            (req,res) => res.sendFile(path.join(__dirname,'html/suite-index.html')));

// How-to
app.get('/how-to', (req,res) => res.sendFile(path.join(__dirname,'html/finops-suite/how-to.html')));

// Status
app.get('/api/status', (req,res) => res.json({
  ok: true, status: 'TSM online', ai: !!process.env.GROQ_API_KEY,
  suites: ['healthcare','finops','insurance'], version: '3.0.0'
}));

// 404
app.use('/api', (req,res) => res.status(404).json({ ok: false, error: 'API route not found', path: req.path }));
app.use((req,res) => res.status(404).send('Not found: ' + req.path));

const PORT = process.env.PORT || 3000;




// ===============================
// TSM BPO OPS CLOUD · PHASE 3 API
// ===============================
const fs = require("fs");
const BPO_DB = "./data/bpo-tasks.json";

function bpoRead(){
  try { return JSON.parse(fs.readFileSync(BPO_DB,"utf8")); }
  catch(e){
    return {
      tasks:[
        {id:"BPO-1001",client:"Ameris Construction",lane:"Planroom",owner:"Document Lead",sla:"2h",status:"Open",risk:"HIGH",summary:"Blueprint revision conflict needs OCR validation"},
        {id:"BPO-1002",client:"HonorHealth",lane:"Prior Auth",owner:"Compliance Lead",sla:"4h",status:"Open",risk:"HIGH",summary:"Payer delay creating care-flow and revenue risk"},
        {id:"BPO-1003",client:"RR Donnelley",lane:"QA Routing",owner:"Ops Lead",sla:"1h",status:"Review",risk:"MED",summary:"Mail batch exception queue requires release approval"},
        {id:"BPO-1004",client:"Allure Beauty Concepts",lane:"AP Recon",owner:"Finance Lead",sla:"Today",status:"Open",risk:"MED",summary:"Vendor payment timing and close readiness issue"}
      ]
    };
  }
}

function bpoWrite(db){
  fs.mkdirSync("./data",{recursive:true});
  fs.writeFileSync(BPO_DB, JSON.stringify(db,null,2));
}

app.get("/api/bpo/tasks",(req,res)=>{
  const db=bpoRead();
  const client=req.query.client;
  const tasks=client ? db.tasks.filter(t=>t.client===client) : db.tasks;
  res.json({ok:true,tasks});
});

app.post("/api/bpo/tasks",(req,res)=>{
  const db=bpoRead();
  const body=req.body||{};
  const task={
    id:"BPO-"+Math.floor(1000+Math.random()*8999),
    client:body.client||"Ameris Construction",
    lane:body.lane||"General",
    owner:body.owner||"Strategist",
    sla:body.sla||"Today",
    status:body.status||"Open",
    risk:body.risk||"MED",
    summary:body.summary||"BPO task created",
    ts:new Date().toISOString()
  };
  db.tasks.unshift(task);
  bpoWrite(db);
  res.json({ok:true,task});
});

app.post("/api/bpo/tasks/:id/status",(req,res)=>{
  const db=bpoRead();
  const task=db.tasks.find(t=>t.id===req.params.id);
  if(!task) return res.status(404).json({ok:false,error:"Task not found"});
  task.status=req.body?.status||task.status;
  task.owner=req.body?.owner||task.owner;
  task.updated_at=new Date().toISOString();
  bpoWrite(db);
  res.json({ok:true,task});
});

app.get("/api/bpo/rollup",(req,res)=>{
  const db=bpoRead();
  const client=req.query.client;
  const tasks=client ? db.tasks.filter(t=>t.client===client) : db.tasks;
  const open=tasks.filter(t=>t.status!=="Done").length;
  const high=tasks.filter(t=>t.risk==="HIGH").length;
  const sla=tasks.filter(t=>/1h|2h|4h/i.test(t.sla)).length;
  res.json({
    ok:true,
    client:client||"ALL CLIENTS",
    open,
    high,
    sla,
    total:tasks.length,
    top_issue:tasks[0]?.summary||"No active issue",
    executive:`EXECUTIVE BPO ROLLUP

CLIENT
${client||"ALL CLIENTS"}

OPEN TASKS
${open}

HIGH RISK
${high}

SLA WATCH
${sla}

BEST NEXT ACTIONS
1. Assign owners for high-risk open items.
2. Clear SLA-watch blockers before end of operating window.
3. Update queue status after each operating cycle.
4. Escalate unresolved risk into Strategist.

CONFIDENCE
92%`
  });
});

app.listen(PORT, () => console.log(`TSM server v3.0 on port ${PORT}`));
