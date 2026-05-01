#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/journey_progression
cp -f "$FILE" "backups/journey_progression/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(errors="ignore")

patch = r'''
<script id="tsm-journey-progress-fix">
(function(){
  if(window.__TSM_JOURNEY_PROGRESS_FIX__) return;
  window.__TSM_JOURNEY_PROGRESS_FIX__ = true;

  window.goStep = window.goStep || function(n){
    document.querySelectorAll(".journey-step").forEach(el=>el.classList.remove("active","done"));
    for(let i=1;i<=5;i++){
      const el=document.getElementById("jstep-"+i);
      if(!el) continue;
      if(i<n) el.classList.add("done");
      if(i===n) el.classList.add("active");
    }
    window.__jStep = n;
  };

  const oldRender = window.render;
  if(typeof oldRender === "function"){
    window.render = function(){
      const result = oldRender.apply(this, arguments);
      setTimeout(()=>window.goStep(2), 250);
      return result;
    };
  }

  document.addEventListener("click", function(e){
    const btn=e.target.closest("button");
    if(!btn) return;
    const txt=(btn.textContent||"").toLowerCase();

    if(txt.includes("pick this") || txt.includes("recommended")){
      setTimeout(()=>window.goStep(3), 150);
    }

    if(txt.includes("improve picked") || txt.includes("refine")){
      setTimeout(()=>window.goStep(4), 300);
    }

    if(txt.includes("lock")){
      setTimeout(()=>window.goStep(5), 300);
    }
  }, true);
})();
</script>
'''

html = re.sub(r'<script id="tsm-journey-progress-fix">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", patch + "\n</body>")

p.write_text(html)
print("journey progression fixed")
PY

git add "$FILE"
git commit -m "fix Music journey step progression" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=journeyfix"
