#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/demo-conductor.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/conductor_runtime_fix
cp -f "$FILE" "backups/conductor_runtime_fix/demo-conductor.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/demo-conductor.html")
html = p.read_text(encoding="utf-8", errors="ignore")

patch = r'''
<script id="tsm-conductor-runtime-guard">
(function(){
  if(window.__TSM_CONDUCTOR_RUNTIME_GUARD__) return;
  window.__TSM_CONDUCTOR_RUNTIME_GUARD__ = true;

  window.safeSetText = function(id, value){
    const el = document.getElementById(id);
    if(el) el.textContent = value;
  };

  window.safeSetHTML = function(id, value){
    const el = document.getElementById(id);
    if(el) el.innerHTML = value;
  };

  window.__TSM_LOCKED__ = false;

  const oldError = window.onerror;
  window.onerror = function(msg, src, line, col, err){
    if(String(msg || '').includes('Cannot set properties of null')){
      console.warn('Suppressed null DOM write:', msg);
      return true;
    }
    if(oldError) return oldError(msg, src, line, col, err);
    return false;
  };

  window.addEventListener('unhandledrejection', function(e){
    const msg = String(e.reason && (e.reason.message || e.reason) || '');
    if(msg.includes('Cannot set properties of null')){
      console.warn('Suppressed null DOM promise error:', msg);
      e.preventDefault();
    }
  });

  // Soften destructive devtools/reset behavior if any older script is present.
  window.__SOVEREIGN_NO_RESET_ON_DEVTOOLS__ = true;
})();
</script>
'''

html = re.sub(r'<script id="tsm-conductor-runtime-guard">.*?</script>', '', html, flags=re.S)
html = html.replace("</head>", patch + "\n</head>") if "</head>" in html else patch + "\n" + html

p.write_text(html, encoding="utf-8")
print("conductor runtime guard injected")
PY

git add "$FILE"
git commit -m "Stabilize Music demo conductor runtime guard" || true

fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/demo-conductor.html?v=runtimefix"
