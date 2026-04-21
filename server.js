const express = require('express');
const path    = require('path');
const fs      = require('fs');
const https   = require('https');
const http    = require('http');

const app  = express();
const PORT = process.env.PORT || 8080;

app.use(express.json({ limit: '2mb' }));

// ── GROQ PROXY ────────────────────────────────────────────────────────────────
// Keeps the API key server-side. Frontend POSTs here instead of Groq directly.
// Set GROQ_API_KEY in your Fly.io secrets:
//   fly secrets set GROQ_API_KEY=gsk_...
app.post('/api/groq', async (req, res) => {
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(500).json({ error: 'GROQ_API_KEY not set on server' });

  const { messages, model = 'llama-3.3-70b-versatile', max_tokens = 1200, stream = true } = req.body;
  if (!messages?.length) return res.status(400).json({ error: 'messages required' });

  try {
    const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer ' + key,
      },
      body: JSON.stringify({ model, max_tokens, stream, messages }),
    });

    if (!groqRes.ok) {
      const err = await groqRes.json().catch(() => ({}));
      return res.status(groqRes.status).json({ error: err?.error?.message || 'Groq error' });
    }

    // Stream straight through to the client
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('X-Accel-Buffering', 'no');

    const reader = groqRes.body.getReader();
    const push = async () => {
      while (true) {
        const { done, value } = await reader.read();
        if (done) { res.end(); break; }
        res.write(value);
      }
    };
    push().catch(() => res.end());

  } catch (e) {
    console.error('[/api/groq]', e.message);
    res.status(502).json({ error: 'Proxy error: ' + e.message });
  }
});

// ── APP HEALTH CHECK ──────────────────────────────────────────────────────────
// Suite builder pings this to know which app cards are live vs placeholder.
// GET /api/ping?url=https://tsm-shell.fly.dev/html/honorhealth/
app.get('/api/ping', async (req, res) => {
  const { url } = req.query;
  if (!url) return res.status(400).json({ error: 'url required' });

  // Only allow pinging our own domains for safety
  const allowed = ['tsm-shell.fly.dev', 'tsmatter.com', 'clients.tsmatter.com', 'tsm-core.fly.dev'];
  let hostname;
  try { hostname = new URL(url).hostname; } catch { return res.json({ live: false }); }
  if (!allowed.some(d => hostname === d || hostname.endsWith('.' + d))) {
    return res.json({ live: false });
  }

  try {
    const mod = url.startsWith('https') ? https : http;
    const live = await new Promise(resolve => {
      const req2 = mod.get(url, { timeout: 4000 }, r => resolve(r.statusCode < 400));
      req2.on('error', () => resolve(false));
      req2.on('timeout', () => { req2.destroy(); resolve(false); });
    });
    res.json({ live });
  } catch {
    res.json({ live: false });
  }
});

// ── SUITE DEPLOY ──────────────────────────────────────────────────────────────
// Builds a shareable HTML suite page and saves it to /html/suite/<slug>/index.html
// POST /api/suite  { title, audience, apps: [{name, url}], narratives: {url: text} }
app.post('/api/suite', (req, res) => {
  const { title, audience, apps, narratives = {}, slug: rawSlug } = req.body;
  if (!title || !apps?.length) return res.status(400).json({ error: 'title and apps required' });

  const slug = (rawSlug || title)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 60) || 'suite-' + Date.now();

  const suiteDir = path.join(__dirname, 'html', 'suite', slug);
  try { fs.mkdirSync(suiteDir, { recursive: true }); } catch {}

  const appCards = apps.map((a, i) => {
    const openUrl = a.url.startsWith('http') ? a.url : 'https://tsm-shell.fly.dev' + a.url;
    const narrative = narratives[a.url] || '';
    const narBlock = narrative
      ? `<div class="narr">${narrative.replace(/</g,'&lt;').replace(/\n/g,'<br>')}</div>`
      : '';
    return `
    <div class="app-card" onclick="window.open('${openUrl}','_blank')">
      <div class="app-num">${String(i+1).padStart(2,'0')}</div>
      <div class="app-body">
        <div class="app-name">${a.name}</div>
        <div class="app-url">${a.url}</div>
        ${narBlock}
      </div>
      <div class="app-arrow">↗</div>
    </div>`;
  }).join('\n');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>${title} · TSM Suite</title>
<link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@300;400;500&family=Bebas+Neue&display=swap" rel="stylesheet">
<style>
:root{--bg:#04080f;--gold:#c9a84c;--gold2:#e8c87a;--border:rgba(100,200,255,0.08);--border2:rgba(201,168,76,0.3);--text:#b8cfe2;--dim:#3a5070;--bright:#eef4ff;--glass:rgba(13,24,40,0.6);--green:#10b981;}
*{box-sizing:border-box;margin:0;padding:0;}
body{background:var(--bg);color:var(--text);font-family:'DM Mono',monospace;min-height:100vh;padding:0;}
body::before{content:'';position:fixed;inset:0;background:radial-gradient(ellipse 80% 60% at 10% 0%,rgba(201,168,76,.07) 0%,transparent 55%),radial-gradient(ellipse 60% 50% at 90% 100%,rgba(20,120,200,.08) 0%,transparent 55%);pointer-events:none;}
.header{padding:32px 40px 24px;border-bottom:0.5px solid var(--border);background:rgba(4,8,15,.9);backdrop-filter:blur(20px);position:sticky;top:0;z-index:10;}
.logo{font-family:'Bebas Neue',sans-serif;font-size:18px;color:var(--gold);letter-spacing:3px;margin-bottom:6px;}
.suite-title{font-size:22px;font-weight:500;color:var(--bright);letter-spacing:1px;}
.suite-meta{font-size:10px;color:var(--dim);letter-spacing:2px;margin-top:4px;text-transform:uppercase;}
.content{max-width:900px;margin:0 auto;padding:36px 40px;}
.section-label{font-size:9px;letter-spacing:3px;text-transform:uppercase;color:var(--dim);margin-bottom:14px;border-bottom:0.5px solid var(--border);padding-bottom:6px;}
.app-card{display:flex;align-items:flex-start;gap:16px;padding:16px 18px;border:0.5px solid var(--border);border-radius:10px;background:var(--glass);backdrop-filter:blur(16px);margin-bottom:8px;cursor:pointer;transition:all .15s;position:relative;overflow:hidden;}
.app-card::before{content:'';position:absolute;inset:0;background:linear-gradient(135deg,rgba(255,255,255,.04) 0%,transparent 60%);pointer-events:none;}
.app-card:hover{border-color:rgba(201,168,76,.4);transform:translateX(3px);box-shadow:0 4px 24px rgba(0,0,0,.3);}
.app-num{font-family:'Bebas Neue',sans-serif;font-size:28px;color:var(--gold);opacity:.4;min-width:36px;line-height:1;}
.app-body{flex:1;}
.app-name{font-size:13px;font-weight:500;color:var(--bright);margin-bottom:3px;}
.app-url{font-size:9px;color:var(--dim);margin-bottom:6px;}
.narr{font-size:10px;color:var(--text);line-height:1.7;padding:8px 10px;background:rgba(0,0,0,.2);border-left:2px solid var(--gold);border-radius:4px;margin-top:6px;}
.app-arrow{font-size:16px;color:var(--dim);opacity:.4;margin-top:4px;transition:all .15s;}
.app-card:hover .app-arrow{color:var(--gold);opacity:1;}
.dot{width:5px;height:5px;border-radius:50%;background:var(--green);display:inline-block;margin-right:6px;box-shadow:0 0 5px var(--green);}
.footer{padding:32px 40px;border-top:0.5px solid var(--border);text-align:center;font-size:9px;color:var(--dim);letter-spacing:2px;text-transform:uppercase;}
</style>
</head>
<body>
<div class="header">
  <div class="logo">TSM</div>
  <div class="suite-title">${title}</div>
  <div class="suite-meta"><span class="dot"></span>Live Suite · ${apps.length} apps · Audience: ${audience || 'General'}</div>
</div>
<div class="content">
  <div class="section-label">Presentation Sequence</div>
  ${appCards}
</div>
<div class="footer">TSM Matter · tsm-shell.fly.dev · Built with Suite Builder</div>
</body>
</html>`;

  try {
    fs.writeFileSync(path.join(suiteDir, 'index.html'), html);
    const suiteUrl = `https://tsm-shell.fly.dev/html/suite/${slug}/`;
    res.json({ ok: true, url: suiteUrl, slug });
  } catch (e) {
    console.error('[/api/suite]', e.message);
    res.status(500).json({ error: 'Failed to write suite: ' + e.message });
  }
});

// ── EXISTING ROUTES ───────────────────────────────────────────────────────────
app.get('/api/status', (req, res) => {
  res.json({
    status: 'SOVEREIGN ONLINE',
    valuation: '$600,000',
    bridge: 'CONNECTED',
    groq: !!process.env.GROQ_API_KEY ? 'READY' : 'NO KEY',
  });
});

app.use(express.static(__dirname));

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, () => console.log(`TSM Shell · port ${PORT}`));
