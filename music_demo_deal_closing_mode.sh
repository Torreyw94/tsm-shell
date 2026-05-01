#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_demo_deal_closing

cp -f server.js "backups/music_demo_deal_closing/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_demo_deal_closing/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_demo_deal_closing/index2.$STAMP.bak"
cp -f html/music-command/presentation-live.html "backups/music_demo_deal_closing/presentation-live.$STAMP.bak"
cp -f html/music-command/how-to-guide.html "backups/music_demo_deal_closing/how-to-guide.$STAMP.bak"
cp -f html/music-command/marketing.html "backups/music_demo_deal_closing/marketing.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Make tokens more unique if original function exists
text = text.replace(
  'const token = crypto.randomBytes(18).toString("hex");',
  'const token = crypto.randomBytes(24).toString("hex") + Date.now();'
)

# Extend token record defaults inside makeDemoToken
text = text.replace(
'''watermark: `ZY MUSIC COMMAND · ${client} · ${token.slice(0,6)}`''',
'''watermark: `ZY MUSIC COMMAND · ${client} · ${token.slice(0,6)}`,
    maxViews: 3,
    maxApiHits: 15,
    views: 0,
    locked: false,
    lockReason: null,
    events: []'''
)

# Strengthen validateDemoAccess
old_validate = r'''function validateDemoAccess(req){
  const token = getDemoToken(req);
  if(!token) return { ok:false, error:"Missing demo token" };

  const record = global.MUSIC_DEMO_ACCESS.tokens[token];
  if(!record) return { ok:false, error:"Invalid demo token" };

  if(Date.now() > record.expiresAt){
    return { ok:false, error:"Demo token expired" };
  }

  return { ok:true, token, record };
}'''

new_validate = r'''function validateDemoAccess(req){
  const token = getDemoToken(req);
  if(!token) return { ok:false, error:"Missing demo token" };

  const record = global.MUSIC_DEMO_ACCESS.tokens[token];
  if(!record) return { ok:false, error:"Invalid demo token" };

  if(record.locked){
    return { ok:false, error:record.lockReason || "Demo link locked" };
  }

  if(Date.now() > record.expiresAt){
    record.locked = true;
    record.lockReason = "Demo token expired";
    return { ok:false, error:"Demo token expired" };
  }

  const usage = global.MUSIC_DEMO_ACCESS.usage[token];
  if(usage && usage.hits >= (record.maxApiHits || 15)){
    record.locked = true;
    record.lockReason = "Demo usage limit reached";
    return { ok:false, error:"Demo usage limit reached" };
  }

  return { ok:true, token, record };
}'''

if old_validate in text:
    text = text.replace(old_validate, new_validate)

# Add deal-closing routes before API 404
block = r'''
// ===== MUSIC DEMO DEAL-CLOSING MODE =====
function recordDemoEvent(token, type, detail){
  const record = global.MUSIC_DEMO_ACCESS.tokens[token];
  if(!record) return null;

  const event = {
    id: Date.now(),
    type,
    detail: detail || "",
    createdAt: new Date().toISOString()
  };

  record.events = record.events || [];
  record.events.unshift(event);
  record.events = record.events.slice(0, 50);

  return event;
}

app.post('/api/music/demo/view', (req, res) => {
  const access = validateDemoAccess(req);
  if(!access.ok) return res.status(401).json({ ok:false, error:access.error, locked:true });

  const record = access.record;
  record.views = (record.views || 0) + 1;

  if(record.views > (record.maxViews || 3)){
    record.locked = true;
    record.lockReason = "Demo view limit reached";
    recordDemoEvent(access.token, "locked", "View limit reached");
    return res.status(403).json({ ok:false, error:"Demo view limit reached", locked:true, record });
  }

  const event = recordDemoEvent(access.token, "viewed", `Demo opened by ${record.client}`);
  const usage = trackMusicUsage(req, "demo_view");

  const hoursLeft = Math.max(0, Math.ceil((record.expiresAt - Date.now()) / (60 * 60 * 1000)));
  const viewsLeft = Math.max(0, (record.maxViews || 3) - record.views);

  return res.json({
    ok:true,
    viewed:true,
    event,
    usage,
    demo:record,
    urgency:{
      hoursLeft,
      viewsLeft,
      message: `Private demo link expires in ${hoursLeft} hour(s) or ${viewsLeft} view(s).`
    }
  });
});

app.post('/api/music/demo/lock', (req, res) => {
  const body = req.body || {};
  const token = body.token || getDemoToken(req);
  const record = global.MUSIC_DEMO_ACCESS.tokens[token];

  if(!record) return res.status(404).json({ ok:false, error:"Token not found" });

  record.locked = true;
  record.lockReason = body.reason || "Locked by owner";
  recordDemoEvent(token, "locked", record.lockReason);

  return res.json({ ok:true, demo:record });
});

app.post('/api/music/demo/unlock', (req, res) => {
  const body = req.body || {};
  const token = body.token || getDemoToken(req);
  const record = global.MUSIC_DEMO_ACCESS.tokens[token];

  if(!record) return res.status(404).json({ ok:false, error:"Token not found" });

  record.locked = false;
  record.lockReason = null;
  recordDemoEvent(token, "unlocked", "Unlocked by owner");

  return res.json({ ok:true, demo:record });
});

app.get('/api/music/demo/deal-room', (req, res) => {
  return res.json({
    ok:true,
    tokens:Object.values(global.MUSIC_DEMO_ACCESS.tokens).map(t => ({
      token:t.token,
      client:t.client,
      createdAt:t.createdAt,
      expiresAt:t.expiresAt,
      views:t.views || 0,
      maxViews:t.maxViews || 3,
      maxApiHits:t.maxApiHits || 15,
      locked:!!t.locked,
      lockReason:t.lockReason || null,
      watermark:t.watermark,
      events:t.events || []
    })),
    usage:global.MUSIC_DEMO_ACCESS.usage
  });
});
// ===== END MUSIC DEMO DEAL-CLOSING MODE =====
'''

text = re.sub(
  r'\n// ===== MUSIC DEMO DEAL-CLOSING MODE =====.*?// ===== END MUSIC DEMO DEAL-CLOSING MODE =====\s*',
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
print("server deal-closing demo layer inserted")
PY

python3 <<'PY'
from pathlib import Path
import re

client = r'''
<script id="tsm-demo-deal-closing-ui">
(function(){
  if(window.__TSM_DEMO_DEAL_CLOSING_UI__) return;
  window.__TSM_DEMO_DEAL_CLOSING_UI__ = true;

  const token = new URLSearchParams(location.search).get('demo_token') || localStorage.getItem('tsm_music_demo_token');

  function banner(msg, mode){
    let el = document.getElementById('tsm-demo-urgency-banner');
    if(!el){
      el = document.createElement('div');
      el.id = 'tsm-demo-urgency-banner';
      el.style.cssText = `
        position:fixed;
        top:12px;
        left:50%;
        transform:translateX(-50%);
        z-index:999998;
        max-width:760px;
        width:calc(100% - 32px);
        padding:10px 14px;
        border-radius:999px;
        font-family:monospace;
        font-size:11px;
        letter-spacing:.08em;
        text-align:center;
        pointer-events:none;
        backdrop-filter:blur(14px);
      `;
      document.body.appendChild(el);
    }

    const danger = mode === 'danger';
    el.style.background = danger ? 'rgba(127,29,29,.78)' : 'rgba(5,10,20,.78)';
    el.style.border = danger ? '1px solid rgba(251,113,133,.6)' : '1px solid rgba(20,241,149,.35)';
    el.style.color = danger ? '#fecdd3' : '#bbf7d0';
    el.textContent = msg;
  }

  function upgradePrompt(reason){
    let modal = document.getElementById('tsm-demo-upgrade-prompt');
    if(!modal){
      modal = document.createElement('div');
      modal.id = 'tsm-demo-upgrade-prompt';
      modal.style.cssText = `
        position:fixed;
        right:18px;
        bottom:58px;
        z-index:999997;
        width:340px;
        background:#050b14;
        border:1px solid rgba(168,85,247,.45);
        border-radius:16px;
        padding:16px;
        box-shadow:0 0 36px rgba(168,85,247,.18);
        color:#fff;
        font-family:Arial,sans-serif;
      `;
      document.body.appendChild(modal);
    }

    modal.innerHTML = `
      <div style="font-family:monospace;font-size:10px;color:#a855f7;letter-spacing:.14em;text-transform:uppercase">Next Step</div>
      <h3 style="margin:8px 0 6px">Unlock the full Music Command system</h3>
      <p style="margin:0 0 12px;color:#9ca3af;font-size:13px;line-height:1.45">${reason || 'You have seen the live engine. Upgrade or book a walkthrough to continue.'}</p>
      <div style="display:flex;gap:8px">
        <a href="/html/music-command/marketing.html?demo_token=${encodeURIComponent(token || '')}" style="flex:1;text-align:center;background:#ffd230;color:#050505;text-decoration:none;border-radius:999px;padding:10px;font-weight:800">View Plans</a>
        <button onclick="document.getElementById('tsm-demo-upgrade-prompt').remove()" style="border:1px solid rgba(255,255,255,.12);background:transparent;color:#fff;border-radius:999px;padding:10px 12px">Later</button>
      </div>
    `;
  }

  async function registerView(){
    if(!token) return;

    try{
      const res = await fetch('/api/music/demo/view?demo_token=' + encodeURIComponent(token), { method:'POST' });
      const data = await res.json();

      if(!data.ok){
        banner(data.error || 'Demo access locked', 'danger');
        upgradePrompt('This private demo link has reached its limit. Request a fresh link or book the full walkthrough.');
        return;
      }

      if(data.urgency && data.urgency.message){
        banner(data.urgency.message, data.urgency.viewsLeft <= 1 ? 'danger' : 'normal');
      }

      window.__TSM_DEMO_DEAL__ = data;
    }catch(e){
      console.warn('demo view tracking failed', e);
    }
  }

  const originalFetch = window.fetch;
  window.fetch = async function(url, opts){
    const response = await originalFetch(url, opts);

    try{
      const saved = localStorage.getItem('tsm_music_demo_token');
      const isMusicApi = String(url).includes('/api/music/');
      if(isMusicApi && saved){
        const deal = window.__TSM_DEMO_DEAL__;
        const usageHits = deal && deal.usage ? deal.usage.hits : 0;

        if(usageHits >= 8){
          setTimeout(() => upgradePrompt('You are actively using the demo. Studio Mode unlocks more runs, exports, and deeper Artist DNA.'), 700);
        }
      }
    }catch(e){}

    return response;
  };

  window.addEventListener('load', function(){
    setTimeout(registerView, 600);
  });
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
    html = re.sub(r'<script id="tsm-demo-deal-closing-ui">.*?</script>', '', html, flags=re.S)
    html = html.replace("</body>", client + "\n</body>") if "</body>" in html else html + "\n" + client
    p.write_text(html, encoding="utf-8")

print("frontend deal-closing UI injected")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html html/music-command/presentation-live.html html/music-command/how-to-guide.html html/music-command/marketing.html
git commit -m "Upgrade Music demo protection to deal-closing mode" || true

fly deploy --local-only

echo
echo "Create a 24h / 3-view deal link:"
echo "curl -s -X POST https://tsm-shell.fly.dev/api/music/demo/create -H 'Content-Type: application/json' -d '{\"client\":\"Artist Prospect\",\"hours\":24}'"
echo
echo "Deal room:"
echo "curl -s https://tsm-shell.fly.dev/api/music/demo/deal-room"
