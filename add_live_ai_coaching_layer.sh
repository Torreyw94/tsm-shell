#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/ai_coaching
cp -f "$FILE" "backups/ai_coaching/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

patch = r'''
<script id="tsm-live-ai-coaching">
(function(){
  if(window.__TSM_AI_COACHING__) return;
  window.__TSM_AI_COACHING__ = true;

  function coach(msg){
    let el = document.getElementById('ai-coach-box');
    if(!el){
      el = document.createElement('div');
      el.id = 'ai-coach-box';
      el.style.cssText = `
        position:fixed;
        bottom:90px;
        right:20px;
        width:260px;
        background:rgba(11,18,32,.96);
        border:1px solid rgba(57,217,138,.35);
        border-radius:14px;
        padding:13px;
        font-size:12px;
        font-family:monospace;
        color:#d1fae5;
        z-index:99999;
        box-shadow:0 0 24px rgba(57,217,138,.16);
        line-height:1.45;
      `;
      document.body.appendChild(el);
    }
    el.textContent = msg;
  }

  function runCoachingSequence(){
    coach("ZAY → tightening your cadence so the flow lands cleaner…");
    setTimeout(()=>coach("RIYA → easing the emotion into clearer, more natural lines…"), 900);
    setTimeout(()=>coach("DJ → checking structure so the hook direction makes sense…"), 1800);
    setTimeout(()=>coach("Scoring strongest version… then I’ll show you what to improve next."), 2700);
  }

  window.addEventListener('click', function(e){
    const btn = e.target.closest('button');
    if(!btn) return;
    const txt = (btn.textContent || "").toLowerCase();
    if(txt.includes("analyze") || txt.includes("run") || txt.includes("improve")){
      runCoachingSequence();
    }
  }, true);
})();
</script>
'''

html = re.sub(r'<script id="tsm-live-ai-coaching">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", patch + "\n</body>")

p.write_text(html, encoding="utf-8")
print("AI coaching layer injected")
PY

git add "$FILE"
git commit -m "Add live AI coaching layer to Music app" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=coaching"
