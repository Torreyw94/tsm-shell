#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/presentation-live.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/presentation_autorun
cp -f "$FILE" "backups/presentation_autorun/presentation-live.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/presentation-live.html")
html = p.read_text(encoding="utf-8", errors="ignore")

auto_script = r'''
<script id="tsm-auto-run-demo">
(function(){
  if(window.__TSM_AUTO_RUN_DEMO__) return;
  window.__TSM_AUTO_RUN_DEMO__ = true;

  async function autoRun(){
    const input = document.getElementById('demoInput');
    const output = document.getElementById('demoOutput');

    if(!input || !output) return;

    if(!input.value.trim()){
      input.value = `Life surrounded by wrong but trying to stay right is a fight
Every day a battle every night a new light`;
    }

    output.innerText = "Running live demo automatically...\n\nZAY → RIYA → DJ";

    if(typeof runDemo === "function"){
      try{
        await runDemo();
        output.innerText = "LIVE DEMO COMPLETE\n\n" + output.innerText;
      }catch(e){
        output.innerText = "Auto-run failed. Click Run AI Analysis to retry.";
      }
    }
  }

  window.addEventListener("load", function(){
    setTimeout(autoRun, 1000);
  });
})();
</script>
'''

html = re.sub(r'<script id="tsm-auto-run-demo">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", auto_script + "\n</body>")

p.write_text(html, encoding="utf-8")
print("auto-run demo script injected")
PY

git add "$FILE"
git commit -m "Auto-run Music live demo on presentation load" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/presentation-live.html?v=autorun"
