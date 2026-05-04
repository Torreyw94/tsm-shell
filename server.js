require("dotenv").config();
const express = require('express');
const { limiter, aiLimiter, botGuard, apiKeyGuard } = require('./servers/middleware');
const path = require('path');
const app = express();

app.use(express.json({ limit: '10mb' }));


// =====================================================
// MUSIC COMMAND · ZAY AGENT PASS · GROQ ONLY
// =====================================================
app.post('/api/music/agent-pass', express.json({limit:'1mb'}), async (req, res) => {
  const body = req.body || {};
  const agent = String(body.agent || 'ZAY').toUpperCase();
  const step = body.step || 'Draft';
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

Output format:
HOOK OPTION 1:
...

HOOK OPTION 2:
...

PRODUCER NOTE:
...`;

  const user = draft || 'Create a hook with pressure and comeback energy.';

  function zayFallback(){
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

app.use(express.static(path.join(__dirname, 'html')));
app.use(express.static(path.join(__dirname, 'public')));

// Suite routers — clean, separated, no cross-contamination
// Security
app.use(limiter);
app.use(botGuard);
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
app.listen(PORT, () => console.log(`TSM server v3.0 on port ${PORT}`));
