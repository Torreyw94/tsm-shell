#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/demo_narration
cp -f "$FILE" "backups/demo_narration/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

replacements = {
"Paste a verse, hook, or raw concept.":"Paste your lyrics. Don’t overthink it. We’ll figure out what actually works.",
"Run Full Chain":"⚡ Analyze & Improve My Song",
"Hit Score":"Strong foundation. Not release-ready yet.",
"Iterate Again":"This isn’t the best version yet. Let’s improve it.",
"Pick This":"⭐ Strongest Direction — Use This",
"First run captured":"Your song is improving. Keep going.",
"Promising. Pick the best version and rerun once more.":"Not ready yet. One more pass could make this a strong release."
}

for old,new in replacements.items():
    html = html.replace(old,new)

patch = r'''
<script id="tsm-demo-narration-layer">
(function(){
  if(window.__TSM_DEMO_NARRATION_LAYER__) return;
  window.__TSM_DEMO_NARRATION_LAYER__ = true;

  function toast(msg){
    const el=document.createElement('div');
    el.textContent=msg;
    el.style.cssText='position:fixed;bottom:24px;left:50%;transform:translateX(-50%);z-index:99999;background:#0b1220;color:#fff;border:1px solid rgba(57,217,138,.45);padding:11px 16px;border-radius:999px;font-size:12px;font-family:monospace;box-shadow:0 0 26px rgba(57,217,138,.14)';
    document.body.appendChild(el);
    setTimeout(()=>el.remove(),2500);
  }

  window.showToast = window.showToast || toast;

  const oldImprove = window.improveRecommended;
  if(typeof oldImprove === 'function'){
    window.improveRecommended = function(){
      toast('Applying strongest direction… improving your song');
      return oldImprove.apply(this, arguments);
    };
  }

  const oldRender = window.render;
  if(typeof oldRender === 'function'){
    window.render = function(){
      const before = parseInt((document.getElementById('hitScore')||{}).textContent)||0;
      const result = oldRender.apply(this, arguments);
      setTimeout(()=>{
        const score = parseInt((document.getElementById('hitScore')||{}).textContent)||0;
        if(score >= 85) toast('This is a strong version. Most creators stop here.');
        else if(score > before && before) toast('This is better. You’re seeing why this version works.');
      },120);
      return result;
    };
  }
})();
</script>
'''

html = re.sub(r'<script id="tsm-demo-narration-layer">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", patch + "\n</body>")

p.write_text(html, encoding="utf-8")
print("demo narration layer applied")
PY

git add "$FILE"
git commit -m "Tighten Music app in-app demo narration" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=narration2"
