#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_protection_layer

cp -f server.js "backups/music_protection_layer/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_protection_layer/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_protection_layer/index2.$STAMP.bak"
cp -f html/music-command/presentation-live.html "backups/music_protection_layer/presentation-live.$STAMP.bak"
cp -f html/music-command/marketing.html "backups/music_protection_layer/marketing.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

block = r'''
// ===== MUSIC PROTECTION LAYER =====
const crypto = require('crypto');

global.MUSIC_DEMO_ACCESS = global.MUSIC_DEMO_ACCESS || {
  tokens: {},
  usage: {}
};

function makeDemoToken(client="demo", hours=48){
  const token = crypto.randomBytes(18).toString("hex");
  const expiresAt = Date.now() + Number(hours || 48) * 60 * 60 * 1000;

  global.MUSIC_DEMO_ACCESS.tokens[token] = {
    token,
    client,
    expiresAt,
    createdAt: new Date().toISOString(),
    watermark: `ZY MUSIC COMMAND · ${client} · ${token.slice(0,6)}`
  };

  return global.MUSIC_DEMO_ACCESS.tokens[token];
}

function getDemoToken(req){
  return (
    req.query.demo_token ||
    req.headers["x-demo-token"] ||
    req.headers["authorization"]?.replace(/^Bearer\s+/i, "")
  );
}

function validateDemoAccess(req){
  const token = getDemoToken(req);
  if(!token) return { ok:false, error:"Missing demo token" };

  const record = global.MUSIC_DEMO_ACCESS.tokens[token];
  if(!record) return { ok:false, error:"Invalid demo token" };

  if(Date.now() > record.expiresAt){
    return { ok:false, error:"Demo token expired" };
  }

  return { ok:true, token, record };
}

function trackMusicUsage(req, action){
  const token = getDemoToken(req) || "public";
  const access = global.MUSIC_DEMO_ACCESS.tokens[token] || {
    client:"public",
    watermark:"ZY MUSIC COMMAND · PUBLIC"
  };

  if(!global.MUSIC_DEMO_ACCESS.usage[token]){
    global.MUSIC_DEMO_ACCESS.usage[token] = {
      token,
      client: access.client,
      hits: 0,
      actions: {},
      firstSeen: new Date().toISOString(),
      lastSeen: null
    };
  }

  const usage = global.MUSIC_DEMO_ACCESS.usage[token];
  usage.hits += 1;
  usage.lastSeen = new Date().toISOString();
  usage.actions[action] = (usage.actions[action] || 0) + 1;

  return usage;
}

function requireMusicDemo(req, res, next){
  // Allow local/dev and public marketing page access through normal static.
  if(req.path.includes("/api/music/demo/create")) return next();

  const access = validateDemoAccess(req);
  if(!access.ok){
    return res.status(401).json({
      ok:false,
      protected:true,
      error:access.error,
      message:"This Music Command demo requires an active share link."
    });
  }

  req.musicDemo = access.record;
  trackMusicUsage(req, req.path);
  next();
}

app.post('/api/music/demo/create', (req, res) => {
  const body = req.body || {};
  const client = body.client || "prospect";
  const hours = body.hours || 48;
  const record = makeDemoToken(client, hours);

  return res.json({
    ok:true,
    demo:record,
    links:{
      app:`/html/music-command/index.html?demo_token=${record.token}`,
      exec:`/html/music-command/index2.html?demo_token=${record.token}`,
      presentation:`/html/music-command/presentation-live.html?demo_token=${record.token}`,
      marketing:`/html/music-command/marketing.html?demo_token=${record.token}`
    }
  });
});

app.get('/api/music/demo/validate', (req, res) => {
  const access = validateDemoAccess(req);
  if(!access.ok) return res.status(401).json({ ok:false, error:access.error });

  const usage = trackMusicUsage(req, "validate");
  return res.json({
    ok:true,
    demo:access.record,
    watermark:access.record.watermark,
    usage
  });
});

app.get('/api/music/demo/usage', (req, res) => {
  return res.json({
    ok:true,
    usage:global.MUSIC_DEMO_ACCESS.usage,
    tokens:Object.values(global.MUSIC_DEMO_ACCESS.tokens).map(t => ({
      client:t.client,
      token:t.token,
      createdAt:t.createdAt,
      expiresAt:t.expiresAt,
      watermark:t.watermark
    }))
  });
});
// ===== END MUSIC PROTECTION LAYER =====
'''

text = re.sub(
  r'\n// ===== MUSIC PROTECTION LAYER =====.*?// ===== END MUSIC PROTECTION LAYER =====\s*',
  '\n',
  text,
  flags=re.S
)

idx = text.find("app.use((req, res) => {")
if idx == -1:
  idx = text.find("res.status(404).json({ ok: false, error: 'API route not found' });")
if idx == -1:
  raise SystemExit("API 404 block not found")

text = text[:idx] + block + "\n" + text[idx:]

p.write_text(text, encoding="utf-8")
print("server protection routes inserted")
PY

python3 <<'PY'
from pathlib import Path
import re

guard = r'''
<script id="tsm-music-demo-protection">
(function(){
  if(window.__TSM_MUSIC_DEMO_PROTECTION__) return;
  window.__TSM_MUSIC_DEMO_PROTECTION__ = true;

  const params = new URLSearchParams(location.search);
  const token = params.get('demo_token') || localStorage.getItem('tsm_music_demo_token');

  if(token){
    localStorage.setItem('tsm_music_demo_token', token);
  }

  async function validateDemo(){
    // Marketing page can remain viewable but still watermarked if token exists.
    const isMarketing = location.pathname.includes('/marketing.html');

    if(!token && !isMarketing){
      document.body.innerHTML = `
        <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:#07080d;color:#fff;font-family:Arial;padding:24px">
          <div style="max-width:560px;border:1px solid rgba(168,85,247,.45);background:#0d1018;border-radius:18px;padding:28px">
            <div style="font-family:monospace;color:#a855f7;letter-spacing:.14em;text-transform:uppercase;font-size:12px">Protected Demo</div>
            <h1 style="margin:12px 0 8px">Demo access required</h1>
            <p style="color:#9ca3af;line-height:1.6">This Music Command experience requires a private share link. Ask for a current demo token to continue.</p>
          </div>
        </div>`;
      return;
    }

    if(!token) return;

    try{
      const res = await fetch('/api/music/demo/validate?demo_token=' + encodeURIComponent(token));
      const data = await res.json();

      if(!data.ok && !isMarketing){
        document.body.innerHTML = `
          <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:#07080d;color:#fff;font-family:Arial;padding:24px">
            <div style="max-width:560px;border:1px solid rgba(251,113,133,.45);background:#0d1018;border-radius:18px;padding:28px">
              <div style="font-family:monospace;color:#fb7185;letter-spacing:.14em;text-transform:uppercase;font-size:12px">Access Expired</div>
              <h1 style="margin:12px 0 8px">Demo link expired</h1>
              <p style="color:#9ca3af;line-height:1.6">Request a fresh Music Command demo link.</p>
            </div>
          </div>`;
        return;
      }

      if(data.watermark){
        const wm = document.createElement('div');
        wm.id = 'tsm-demo-watermark';
        wm.textContent = data.watermark;
        wm.style.cssText = `
          position:fixed;
          right:14px;
          bottom:14px;
          z-index:999999;
          pointer-events:none;
          font-family:monospace;
          font-size:10px;
          letter-spacing:.12em;
          color:rgba(255,255,255,.42);
          background:rgba(0,0,0,.35);
          border:1px solid rgba(255,255,255,.08);
          padding:6px 8px;
          border-radius:999px;
        `;
        document.body.appendChild(wm);
      }

      window.__TSM_DEMO_ACCESS__ = data;
    }catch(e){
      console.warn('Demo validation failed', e);
    }
  }

  validateDemo();

  const originalFetch = window.fetch;
  window.fetch = function(url, opts){
    opts = opts || {};
    opts.headers = opts.headers || {};

    const saved = localStorage.getItem('tsm_music_demo_token');
    if(saved && String(url).includes('/api/music/')){
      opts.headers['X-Demo-Token'] = saved;
    }

    return originalFetch(url, opts);
  };
})();
</script>
'''

files = [
  "html/music-command/index.html",
  "html/music-command/index2.html",
  "html/music-command/presentation-live.html",
  "html/music-command/how-to-guide.html",
  "html/music-command/marketing.html"
]

for rel in files:
    p = Path(rel)
    if not p.exists():
        continue

    html = p.read_text(encoding="utf-8", errors="ignore")
    html = re.sub(r'<script id="tsm-music-demo-protection">.*?</script>', '', html, flags=re.S)

    if "</body>" in html:
        html = html.replace("</body>", guard + "\n</body>")
    else:
        html += "\n" + guard

    p.write_text(html, encoding="utf-8")

print("frontend demo protection injected")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html html/music-command/presentation-live.html html/music-command/how-to-guide.html html/music-command/marketing.html
git commit -m "Add protected Music Command demo access layer" || true

fly deploy --local-only

echo
echo "Create a private demo token:"
echo "curl -s -X POST https://tsm-shell.fly.dev/api/music/demo/create -H 'Content-Type: application/json' -d '{\"client\":\"Artist Prospect\",\"hours\":48}'"
