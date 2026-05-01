#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.restorebak.$(date +%s)"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# Inject Dee container + script cleanly
inject = """
<script>
(function(){

  // CREATE Dee container
  var dee = document.createElement('div');
  dee.id = "dee-command-center";
  dee.innerHTML = "<div style='padding:40px;color:#00ffa3;font-family:monospace;font-size:18px;'>Dee War Room Loading...</div>";

  // Insert at top
  document.body.insertBefore(dee, document.body.firstChild);

  // Load real data
  fetch('/api/honor/dee/dashboard', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({system:'HonorHealth'})
  })
  .then(r=>r.json())
  .then(d=>{
    dee.innerHTML = "<pre style='padding:20px;color:#00ffa3;font-size:12px;'>" +
      JSON.stringify(d, null, 2) +
    "</pre>";
  })
  .catch(e=>{
    dee.innerHTML = "<div style='color:red;padding:20px;'>Dee failed to load</div>";
  });

})();
</script>
"""

if "dee-command-center" not in text:
    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("✅ Dee restored cleanly")
PY

git add "$FILE"
git commit -m "Restore Dee war room injection cleanly" || true
git push origin main || true
fly deploy
