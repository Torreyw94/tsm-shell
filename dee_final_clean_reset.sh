#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.finalbak.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. REMOVE ALL previous injected scripts
text = re.sub(r'<script>.*?(dee|override|command-center).*?</script>', '', text, flags=re.S | re.I)

# 2. REMOVE any global hide rules
text = re.sub(r'body>\*:not\([^)]*\)\{display:none[^}]*\}', '', text)

# 3. REMOVE duplicate dee containers
text = re.sub(r'<div id="dee-command-center".*?</div>', '', text, flags=re.S)

# 4. ADD CLEAN Dee (NO CSS HIDING ANYTHING)
inject = """
<div id="dee-command-center" style="
  display:block;
  position:relative;
  width:100%;
  max-width:1400px;
  margin:0 auto;
  padding:32px;
  background:#050b14;
  color:#00ffa3;
  font-family:monospace;
">

  <div id="dee-loading" style="font-size:20px;margin-bottom:20px;">
    Dee War Room Live
  </div>

  <div id="dee-content">Loading...</div>

</div>

<script>
(function(){

  var dee = document.getElementById('dee-content');

  fetch('/api/honor/dee/dashboard', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({system:'HonorHealth'})
  })
  .then(function(r){ return r.json(); })
  .then(function(d){

    dee.innerHTML =
      '<pre style="font-size:12px;line-height:1.5;">' +
      JSON.stringify(d, null, 2) +
      '</pre>';

  })
  .catch(function(){
    dee.innerHTML = '<div style="color:red;">Failed to load Dee</div>';
  });

})();
</script>
"""

# Inject at END
text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("✅ FULL CLEAN RESET APPLIED")
PY

git add "$FILE"
git commit -m "Final clean reset: remove all overrides + restore Dee cleanly" || true
git push origin main || true
fly deploy
