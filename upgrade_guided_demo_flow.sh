#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/presentation-live.html"
BACKUP="backups/presentation_guided_$(date +%s).html"

mkdir -p backups
cp -f "$FILE" "$BACKUP"

python3 <<'PY'
from pathlib import Path

p = Path("html/music-command/presentation-live.html")
html = p.read_text(encoding="utf-8", errors="ignore")

# =========================
# INSERT GUIDED STEPS UNDER HERO
# =========================
guided_block = '''
<div id="guided-demo" style="margin-top:20px;padding:16px 18px;border:1px solid rgba(255,255,255,0.08);border-radius:10px;background:rgba(0,0,0,0.25);max-width:720px;">
  <div style="font-size:0.75rem;opacity:0.7;margin-bottom:8px;">GUIDED DEMO</div>

  <div style="font-size:0.9rem;line-height:1.6;">
    <b>Step 1:</b> Click <span style="color:#ffd84d;">Start Live Demo</span><br/>
    <b>Step 2:</b> AI generates <b>3 versions</b> of a song<br/>
    <b>Step 3:</b> Pick the strongest version<br/>
    <b>Step 4:</b> Watch the system improve and score itself
  </div>

  <div style="margin-top:14px;">
    <button onclick="startGuidedDemo()" style="background:#ffd84d;color:#000;border:none;padding:10px 14px;border-radius:6px;font-weight:600;cursor:pointer;">
      ⚡ Start Live Demo (Recommended)
    </button>
  </div>
</div>
'''

html = html.replace(
    'AI songwriting decision engine for artists, producers, and songwriters.',
    'AI songwriting decision engine for artists, producers, and songwriters.' + guided_block
)

# =========================
# INSERT LIVE INPUT RUNNER
# =========================
runner_block = '''
<div id="live-runner" style="margin-top:30px;padding:18px;border:1px solid rgba(255,255,255,0.08);border-radius:10px;background:#0c1018;max-width:720px;">
  <div style="font-size:0.8rem;opacity:0.6;margin-bottom:10px;">TRY YOUR OWN LYRICS</div>

  <textarea id="demoInput" placeholder="Paste your lyrics here..." 
    style="width:100%;height:100px;background:#07090f;border:1px solid rgba(255,255,255,0.08);color:#fff;padding:10px;border-radius:6px;"></textarea>

  <div style="margin-top:10px;">
    <button onclick="runDemo()" style="background:#00ffd0;color:#000;border:none;padding:10px 14px;border-radius:6px;font-weight:600;cursor:pointer;">
      Run AI Analysis
    </button>
  </div>

  <pre id="demoOutput" style="margin-top:12px;font-size:0.75rem;white-space:pre-wrap;"></pre>
</div>
'''

html = html.replace('</section>', runner_block + '\n</section>', 1)

# =========================
# ADD SCRIPT
# =========================
script_block = '''
<script>
function getToken(){
  return new URLSearchParams(window.location.search).get('demo_token');
}

function startGuidedDemo(){
  window.location.href = "/html/music-command/index2.html?demo_token=" + getToken();
}

async function runDemo(){
  const text = document.getElementById('demoInput').value;
  const token = getToken();

  if(!text){
    alert("Paste some lyrics first");
    return;
  }

  const res = await fetch('/api/music/revision/run?demo_token=' + token,{
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify({draft:text, request:"generate 3 options"})
  });

  const data = await res.json();
  document.getElementById('demoOutput').innerText = JSON.stringify(data,null,2);
}
</script>
'''

html = html.replace('</body>', script_block + '\n</body>')

p.write_text(html, encoding="utf-8")
print("Guided demo flow applied")
PY

echo "DONE: Guided demo flow installed"
