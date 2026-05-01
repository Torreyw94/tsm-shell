#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/demo-conductor.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_conductor_pricing
cp -f "$FILE" "backups/music_conductor_pricing/demo-conductor.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/music-command/demo-conductor.html")
html = p.read_text(encoding="utf-8", errors="ignore")

# -----------------------
# URGENCY BANNER
# -----------------------
banner = """
<div id="dealUrgency" style="
position:fixed;
top:0;
left:0;
right:0;
z-index:9999;
background:linear-gradient(90deg,#111827,#065f46);
color:#ecfeff;
padding:8px 14px;
font-size:12px;
font-family:var(--mono);
border-bottom:1px solid rgba(255,255,255,.08);
">
  Private demo active · Limited runs remaining · Access expires soon
</div>
"""

if "dealUrgency" not in html:
    html = html.replace("<body>", "<body>\n" + banner)

# -----------------------
# PRICING + CLOSE BLOCK
# -----------------------
pricing_block = """
<div class="objectionBox" style="
border-color:rgba(251,191,36,.5);
background:rgba(251,191,36,.08);
margin-top:16px;
">
  <h2 style="color:#fde68a;">Access Options (Positioning)</h2>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    “This isn’t priced like a writing tool.<br/>
    It’s closer to a decision engine for your music.”
  </div>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    “There are 3 ways people use this:”<br/><br/>

    • <b>Creator Mode</b> → consistent writing + iteration<br/>
    • <b>Studio Mode</b> → serious track development<br/>
    • <b>Catalog Mode</b> → building multiple release-ready songs
  </div>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    “It usually pays for itself in one stronger release or saved session.”
  </div>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    <b>Close:</b><br/>
    “Based on what you saw… do you want access to use this on your own tracks?”
  </div>

  <div style="font-size:13px;line-height:1.6;">
    <b>Decision Paths:</b><br/>
    • “Try it on one real song” → low friction<br/>
    • “Use it consistently” → creator tier<br/>
    • “Build release-ready tracks” → studio tier
  </div>
</div>
"""

if "Access Options (Positioning)" not in html:
    html = html.replace("</body>", pricing_block + "\n</body>")

# -----------------------
# JS: dynamic urgency feel
# -----------------------
js = """
<script id="urgency-js">
(function(){
  const el = document.getElementById('dealUrgency');
  if(!el) return;

  let runs = 5 + Math.floor(Math.random()*5);
  setInterval(()=>{
    runs--;
    if(runs > 0){
      el.textContent = "Private demo active · " + runs + " guided runs remaining · Access expires soon";
    } else {
      el.textContent = "Demo limit reached · Unlock required to continue";
      el.style.background = "linear-gradient(90deg,#7f1d1d,#450a0a)";
    }
  }, 9000);
})();
</script>
"""

if "urgency-js" not in html:
    html = html.replace("</body>", js + "\n</body>")

p.write_text(html, encoding="utf-8")
print("pricing + urgency layer added")
PY

git add "$FILE"
git commit -m "Add pricing positioning + urgency layer to Music demo conductor" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/demo-conductor.html?v=close2"
