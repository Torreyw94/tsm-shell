#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/demo-conductor.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_instant_unlock
cp -f "$FILE" "backups/music_instant_unlock/demo-conductor.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/music-command/demo-conductor.html")
html = p.read_text(encoding="utf-8", errors="ignore")

css = """
<style id="instant-unlock-css">
.unlockBox{
  margin-top:16px;
  border:1px solid rgba(57,217,138,.45);
  background:rgba(57,217,138,.08);
  border-radius:14px;
  padding:14px;
}
.unlockBox h2{
  color:#86efac;
  font-size:15px;
  margin:0 0 8px;
}
.unlockInput{
  width:100%;
  background:#07080d;
  border:1px solid rgba(255,255,255,.16);
  color:#fff;
  padding:10px 12px;
  border-radius:10px;
  margin:6px 0;
}
.unlockBtn{
  width:100%;
  background:#39d98a;
  color:#020617;
  border:none;
  border-radius:999px;
  padding:11px 14px;
  font-weight:900;
  cursor:pointer;
  margin-top:8px;
}
.unlockResult{
  margin-top:10px;
  white-space:pre-wrap;
  font-family:var(--mono);
  font-size:11px;
  line-height:1.5;
  color:#d1fae5;
}
</style>
"""

if "instant-unlock-css" not in html:
    html = html.replace("</head>", css + "\n</head>")

box = """
<div class="unlockBox">
  <h2>Instant Unlock Flow</h2>
  <div style="font-size:13px;line-height:1.5;color:#d1d5db;margin-bottom:8px;">
    Use this when they say: <b>“Yes, I want access.”</b>
  </div>

  <input class="unlockInput" id="unlockName" placeholder="Artist / Producer Name"/>
  <input class="unlockInput" id="unlockEmail" placeholder="Email or LinkedIn handle"/>
  <select class="unlockInput" id="unlockTier">
    <option value="creator">Creator Mode · $99/mo</option>
    <option value="studio">Studio Mode · $249/mo</option>
    <option value="label">Catalog / Label Mode · $499/mo</option>
  </select>

  <button class="unlockBtn" onclick="instantUnlock()">Unlock Access Now</button>

  <pre class="unlockResult" id="unlockResult">Lead capture + private link will appear here.</pre>
</div>
"""

if "Instant Unlock Flow" not in html:
    html = html.replace("</body>", box + "\n</body>")

js = """
<script id="instant-unlock-js">
async function instantUnlock(){
  const name = document.getElementById('unlockName')?.value || 'Music Prospect';
  const contact = document.getElementById('unlockEmail')?.value || 'No contact entered';
  const tier = document.getElementById('unlockTier')?.value || 'creator';
  const out = document.getElementById('unlockResult');

  if(out) out.textContent = 'Creating private access link...';

  try{
    const res = await fetch('/api/music/demo/create',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({
        client:name + ' · ' + tier,
        hours:72
      })
    });

    const data = await res.json();

    if(!data.ok){
      if(out) out.textContent = 'Unlock failed: ' + (data.error || 'unknown error');
      return;
    }

    const fullLink = location.origin + data.links.presentation;

    const record = {
      name,
      contact,
      tier,
      link:fullLink,
      createdAt:new Date().toISOString()
    };

    const saved = JSON.parse(localStorage.getItem('zy_unlock_leads') || '[]');
    saved.unshift(record);
    localStorage.setItem('zy_unlock_leads', JSON.stringify(saved));

    if(out){
      out.textContent =
`ACCESS UNLOCKED

Name: ${name}
Contact: ${contact}
Tier: ${tier}

Private 72-hour link:
${fullLink}

Say this:
“Perfect — I unlocked your access. Start with one real song, run the full chain, then use Improve Picked Version until the score moves up.”`;
    }
  }catch(e){
    if(out) out.textContent = 'Unlock failed: ' + e.message;
  }
}
</script>
"""

if "instant-unlock-js" not in html:
    html = html.replace("</body>", js + "\n</body>")

p.write_text(html, encoding="utf-8")
print("instant unlock flow added")
PY

git add "$FILE"
git commit -m "Add instant signup unlock flow to Music conductor" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/demo-conductor.html?v=unlock"
