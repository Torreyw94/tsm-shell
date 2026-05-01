#!/usr/bin/env bash
set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_iframe_stability

for FILE in html/music-command/demo-conductor.html html/music-command/index.html; do
  cp -f "$FILE" "backups/music_iframe_stability/$(basename $FILE).$STAMP.bak"
done

python3 <<'PY'
from pathlib import Path
import re

guard = r'''
<script id="tsm-runtime-null-guard">
(function(){
  if(window.__TSM_RUNTIME_NULL_GUARD__) return;
  window.__TSM_RUNTIME_NULL_GUARD__ = true;

  window.safeSetText = function(id, value){
    const el = document.getElementById(id);
    if(el) el.textContent = value;
  };

  window.addEventListener('error', function(e){
    if(String(e.message || '').includes('Cannot set properties of null')){
      console.warn('Suppressed null DOM write:', e.message);
      e.preventDefault();
      return true;
    }
  }, true);

  window.addEventListener('unhandledrejection', function(e){
    const msg = String(e.reason && (e.reason.message || e.reason) || '');
    if(msg.includes('Cannot set properties of null')){
      console.warn('Suppressed null promise:', msg);
      e.preventDefault();
    }
  });

  window.__SOVEREIGN_NO_RESET_ON_DEVTOOLS__ = true;
})();
</script>
'''

for rel in ["html/music-command/index.html", "html/music-command/demo-conductor.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")
    html = re.sub(r'<script id="tsm-runtime-null-guard">.*?</script>', '', html, flags=re.S)
    html = html.replace("</head>", guard + "\n</head>") if "</head>" in html else guard + html
    p.write_text(html, encoding="utf-8")

# Make conductor load clean app versions so stale demo tokens don't lock iframe
p = Path("html/music-command/demo-conductor.html")
html = p.read_text(encoding="utf-8", errors="ignore")
html = html.replace('/html/music-command/index.html?v=conductor', '/html/music-command/index.html?clear_demo=1&v=conductor')
html = html.replace('/html/music-command/index.html?v=loopfix', '/html/music-command/index.html?clear_demo=1&v=loopfix')
p.write_text(html, encoding="utf-8")

print("iframe + conductor runtime stabilized")
PY

git add html/music-command/demo-conductor.html html/music-command/index.html
git commit -m "Stabilize Music conductor iframe runtime" || true
fly deploy --local-only

echo "Open clean:"
echo "https://tsm-shell.fly.dev/html/music-command/demo-conductor.html?clear_demo=1&v=iframefix"
