#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.stablebak.$(date +%s)"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

inject = """
<script>
(function(){
  var style = document.createElement('style');
  style.innerHTML =
    "html,body{margin:0;padding:0;background:#050b14;overflow-y:auto;}" +
    "body>*:not(#dee-command-center):not(script){display:none;}" +
    "#dee-command-center{display:block;position:relative;width:100%;max-width:1400px;margin:0 auto;}" +
    "#dee-command-center *{max-height:none;overflow:visible;}";

  document.head.appendChild(style);

  var dee = document.getElementById('dee-command-center');
  if (dee && document.body.firstChild !== dee) {
    document.body.insertBefore(dee, document.body.firstChild);
  }
})();
</script>
"""

if "stable_runtime_inject" not in text:
    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("✅ Stable runtime override added")
PY

git add "$FILE"
git commit -m "Add stable Dee runtime override" || true
git push origin main || true
fly deploy
