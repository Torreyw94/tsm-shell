#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_monetization_export

cp -f server.js "backups/music_monetization_export/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_monetization_export/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_monetization_export/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

block = r'''
// ===== MUSIC MONETIZATION + EXPORT + SESSIONS =====
global.MUSIC_SESSIONS = global.MUSIC_SESSIONS || {
  artists: {},
  exports: [],
  upsells: [],
  tiers: {
    free: { name:"Free Trial", price:0, hooks:5, exports:false, sessions:1 },
    tier1: { name:"Tier 1", price:99, hooks:25, exports:true, sessions:5 },
    tier2: { name:"Tier 2", price:249, hooks:100, exports:true, sessions:25 },
    tier3: { name:"Tier 3", price:499, hooks:500, exports:true, sessions:100 }
  }
};

function musicArtistKey(name){
  return String(name || "Current Artist").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "current-artist";
}

function ensureMusicArtist(name){
  const key = musicArtistKey(name);
  if(!global.MUSIC_SESSIONS.artists[key]){
    global.MUSIC_SESSIONS.artists[key] = {
      key,
      artist:name || "Current Artist",
      tier:"tier1",
      sessions:[],
      createdAt:new Date().toISOString(),
      updatedAt:new Date().toISOString()
    };
  }
  return global.MUSIC_SESSIONS.artists[key];
}

function cleanCreativeOutput(text){
  return String(text || "")
    .replace(/\[(ZAY|RIYA|DJ)[^\]]*\]/g, "")
    .replace(/^Agent move:.*$/gm, "")
    .replace(/^DNA influence:.*$/gm, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

app.post('/api/music/session/save', (req, res) => {
  const body = req.body || {};
  const artist = ensureMusicArtist(body.artist || "Current Artist");

  const session = {
    id:Date.now(),
    title:body.title || "Untitled Session",
    draft:body.draft || "",
    output:body.output || "",
    score:body.score || null,
    notes:body.notes || "",
    createdAt:new Date().toISOString()
  };

  artist.sessions.unshift(session);
  artist.sessions = artist.sessions.slice(0, global.MUSIC_SESSIONS.tiers[artist.tier].sessions);
  artist.updatedAt = new Date().toISOString();

  return res.json({ ok:true, artist, session });
});

app.get('/api/music/session/:artist', (req, res) => {
  const artist = ensureMusicArtist(req.params.artist || "Current Artist");
  return res.json({ ok:true, artist });
});

app.post('/api/music/hooks/generate10', (req, res) => {
  const body = req.body || {};
  const draft = cleanCreativeOutput(body.draft || "");
  const artist = ensureMusicArtist(body.artist || "Current Artist");

  const hooks = Array.from({length:10}).map((_, i) => ({
    id:i+1,
    title:"Hook Option " + (i+1),
    text:
      i % 3 === 0 ? "Still I rise when the night get heavy" :
      i % 3 === 1 ? "Wrong all around me, but I still move right" :
      "Turn the pain into light when the pressure get tight",
    angle:
      i % 3 === 0 ? "resilience" :
      i % 3 === 1 ? "conflict" :
      "release"
  }));

  global.MUSIC_SESSIONS.upsells.unshift({
    id:Date.now(),
    artist:artist.artist,
    type:"generate10hooks",
    price:25,
    createdAt:new Date().toISOString()
  });

  return res.json({
    ok:true,
    upsell:{ name:"Generate 10 Hooks", price:25 },
    hooks,
    source:draft
  });
});

app.post('/api/music/export', (req, res) => {
  const body = req.body || {};
  const artist = body.artist || "Current Artist";
  const title = body.title || "Music Export";
  const output = cleanCreativeOutput(body.output || body.draft || "");
  const score = body.score || null;

  const doc = [
    "TSM MUSIC COMMAND EXPORT",
    "Artist: " + artist,
    "Title: " + title,
    "Date: " + new Date().toISOString(),
    "",
    "OUTPUT",
    "------",
    output,
    "",
    "SCORE",
    "-----",
    score ? JSON.stringify(score, null, 2) : "No score attached.",
    "",
    "DAW NOTES",
    "---------",
    "Paste the output into Pro Tools, FL Studio, Ableton, Logic, or your writing doc.",
    "Use ZAY for cadence, RIYA for emotion, and DJ for hook/structure refinement."
  ].join("\n");

  const item = {
    id:Date.now(),
    artist,
    title,
    format:"txt",
    content:doc,
    createdAt:new Date().toISOString()
  };

  global.MUSIC_SESSIONS.exports.unshift(item);
  global.MUSIC_SESSIONS.exports = global.MUSIC_SESSIONS.exports.slice(0,50);

  return res.json({ ok:true, export:item });
});

app.get('/api/music/monetization/state', (_req, res) => {
  return res.json({
    ok:true,
    monetization:{
      tiers:global.MUSIC_SESSIONS.tiers,
      upsells:[
        { name:"Generate 10 hooks", price:25 },
        { name:"Commercial rewrite pack", price:30 },
        { name:"Radio-ready polish", price:25 }
      ],
      recentUpsells:global.MUSIC_SESSIONS.upsells,
      exports:global.MUSIC_SESSIONS.exports.slice(0,10)
    },
    sessions:global.MUSIC_SESSIONS
  });
});
// ===== END MUSIC MONETIZATION + EXPORT + SESSIONS =====
'''

text = re.sub(
  r'\n// ===== MUSIC MONETIZATION \+ EXPORT \+ SESSIONS =====.*?// ===== END MUSIC MONETIZATION \+ EXPORT \+ SESSIONS =====\s*',
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
print("server monetization/export/session routes inserted")
PY

python3 <<'PY'
from pathlib import Path
import re

client = r'''
<script id="tsm-music-monetization-ui">
(function(){
  if(window.__TSM_MUSIC_MONETIZATION_UI__) return;
  window.__TSM_MUSIC_MONETIZATION_UI__ = true;

  window.musicCommerce = {
    saveSession(payload){
      return musicSafeFetch('/api/music/session/save', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    generate10Hooks(payload){
      return musicSafeFetch('/api/music/hooks/generate10', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    exportText(payload){
      return musicSafeFetch('/api/music/export', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    monetization(){
      return musicSafeFetch('/api/music/monetization/state');
    }
  };

  window.exportCurrentMusicSession = async function(){
    const outputEl = document.getElementById('stratOutput') || document.querySelector('[data-agent-output]');
    const inputEl = document.querySelector('textarea') || document.getElementById('stratInput');
    const output = outputEl ? (outputEl.innerText || outputEl.textContent || '') : '';
    const draft = inputEl ? (inputEl.value || inputEl.innerText || '') : '';

    const data = await musicCommerce.exportText({
      artist:'Current Artist',
      title:'Working Export',
      output: output || draft
    });

    console.log('Music Export Ready', data);

    if(data.ok){
      const blob = new Blob([data.export.content], { type:'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'TSM_Music_Export.txt';
      a.click();
      URL.revokeObjectURL(url);
    }

    return data;
  };

  window.generateTenHooksUpsell = async function(){
    const inputEl = document.querySelector('textarea') || document.getElementById('stratInput');
    const draft = inputEl ? (inputEl.value || inputEl.innerText || '') : '';
    const data = await musicCommerce.generate10Hooks({ artist:'Current Artist', draft });
    console.log('10 Hook Pack Generated', data);

    const out = document.getElementById('stratOutput') || document.querySelector('[data-agent-output]') || document.getElementById('mainContent');
    if(out && data.ok){
      out.style.display = 'block';
      out.innerHTML = `
        <div style="padding:14px;border:1px solid rgba(168,85,247,.35);border-radius:10px;background:rgba(5,10,20,.96)">
          <div style="font-family:var(--mono);font-size:.58rem;color:#a855f7;text-transform:uppercase;letter-spacing:.14em">Upsell · Generate 10 Hooks · $25</div>
          <div style="margin-top:10px;display:grid;gap:8px">
            ${data.hooks.map(h => `<div style="padding:9px;border:1px solid rgba(255,255,255,.08);border-radius:6px;color:var(--text2)"><b>${h.title}</b><br>${h.text}<br><span style="font-family:var(--mono);font-size:.55rem;color:#14f195">${h.angle}</span></div>`).join('')}
          </div>
        </div>`;
    }

    return data;
  };

  window.saveCurrentArtistSession = async function(){
    const outputEl = document.getElementById('stratOutput') || document.querySelector('[data-agent-output]');
    const inputEl = document.querySelector('textarea') || document.getElementById('stratInput');
    const output = outputEl ? (outputEl.innerText || outputEl.textContent || '') : '';
    const draft = inputEl ? (inputEl.value || inputEl.innerText || '') : '';

    const data = await musicCommerce.saveSession({
      artist:'Current Artist',
      title:'Working Session',
      draft,
      output
    });

    console.log('Artist Session Saved', data);
    return data;
  };

  window.renderMusicCommercePanel = async function(){
    const data = await musicCommerce.monetization();
    let panel = document.getElementById('music-commerce-panel');

    if(!panel){
      panel = document.createElement('section');
      panel.id = 'music-commerce-panel';
      panel.style.cssText = 'margin-top:14px;padding:14px;border:1px solid rgba(168,85,247,.28);background:rgba(5,10,20,.96);border-radius:10px;';
      const target = document.getElementById('mainContent') || document.querySelector('main') || document.body;
      target.appendChild(panel);
    }

    const tiers = data.monetization.tiers;
    panel.innerHTML = `
      <div style="font-family:var(--mono);font-size:.58rem;color:#a855f7;text-transform:uppercase;letter-spacing:.14em">Monetization Layer</div>
      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:10px">
        ${Object.values(tiers).map(t => `
          <div style="border:1px solid rgba(255,255,255,.08);border-radius:8px;padding:10px;background:rgba(255,255,255,.03)">
            <div style="color:var(--text);font-weight:700">${t.name}</div>
            <div style="font-family:var(--mono);color:#14f195;margin-top:4px">$${t.price}/mo</div>
            <div style="font-size:.7rem;color:var(--text2);margin-top:4px">${t.hooks} hooks · ${t.sessions} sessions</div>
          </div>
        `).join('')}
      </div>
      <div style="display:flex;gap:8px;margin-top:12px;flex-wrap:wrap">
        <button class="btn btn-purple" onclick="generateTenHooksUpsell()">Generate 10 Hooks · $25</button>
        <button class="btn" onclick="exportCurrentMusicSession()">Export TXT</button>
        <button class="btn" onclick="saveCurrentArtistSession()">Save Artist Session</button>
      </div>
    `;

    console.log('Music Commerce State', data);
    return data;
  };

  window.addEventListener('load', function(){
    setTimeout(renderMusicCommercePanel, 1200);
  });
})();
</script>
'''

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")
    html = re.sub(r'<script id="tsm-music-monetization-ui">.*?</script>', '', html, flags=re.S)
    html = html.replace("</body>", client + "\n</body>") if "</body>" in html else html + "\n" + client
    p.write_text(html, encoding="utf-8")

print("frontend monetization/export/session UI inserted")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Add Music monetization, export, and artist session memory layer" || true
git push origin main
fly deploy --local-only

echo "Testing monetization state..."
curl -s https://tsm-shell.fly.dev/api/music/monetization/state
echo
