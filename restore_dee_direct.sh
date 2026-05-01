#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.directbak.$(date +%s)"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

block = """
<div id="dee-command-center" style="display:block;position:relative;width:100%;max-width:1400px;margin:0 auto;padding:24px;color:#00ffa3;background:#050b14;font-family:monospace;">
  <div id="dee-loading" style="padding:24px;font-size:18px;">Dee War Room Loading...</div>
</div>

<script>
(function(){
  var dee = document.getElementById('dee-command-center');
  if (!dee) return;

  document.documentElement.style.background = '#050b14';
  document.body.style.background = '#050b14';
  document.body.style.margin = '0';
  document.body.style.padding = '0';

  fetch('/api/honor/dee/dashboard', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({system:'HonorHealth'})
  })
  .then(function(r){ return r.json(); })
  .then(function(d){
    dee.innerHTML =
      '<div style="padding:24px;">' +
      '<div style="font-size:22px;font-weight:700;margin-bottom:16px;">Dee War Room Live</div>' +
      '<pre style="white-space:pre-wrap;font-size:12px;line-height:1.5;color:#00ffa3;">' +
      JSON.stringify(d, null, 2) +
      '</pre>' +
      '</div>';
  })
  .catch(function(e){
    dee.innerHTML = '<div style="color:#ff6b6b;padding:24px;">Dee failed to load</div>';
  });
})();
</script>
"""

if "</body>" in text and "Dee War Room Loading" not in text:
    text = text.replace("</body>", block + "\n</body>")
elif "Dee War Room Loading" not in text:
    text += "\n" + block

p.write_text(text, encoding="utf-8")
print("Dee direct restore written")
PY

grep -n "dee-command-center\|Dee War Room Loading\|api/honor/dee/dashboard" "$FILE"

git add "$FILE"
git commit -m "Restore Dee directly into honor portal" || true
git push origin main || true
fly deploy
