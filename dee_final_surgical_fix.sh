#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.cleanbak.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. REMOVE ALL injected broken scripts
text = re.sub(r'<script>.*?(HARD OVERRIDE|DEE|takeover).*?</script>', '', text, flags=re.S | re.I)

# 2. REMOVE broken style blocks
text = re.sub(r'<style[^>]*dee[^>]*>.*?</style>', '', text, flags=re.S | re.I)

# 3. CLEAN SIMPLE JS (NO TEMPLATE STRINGS)
inject = """
<script>
(function(){
  var s = document.createElement('style');
  s.innerHTML =
    "html,body{height:auto!important;min-height:100%!important;overflow-y:auto!important;overflow-x:hidden!important;background:#050b14!important;}" +
    "body>*:not(#dee-command-center):not(script){display:none!important;}" +
    "#dee-command-center{display:block!important;position:relative!important;width:100%!important;max-width:1400px;margin:0 auto;}" +
    "#dee-command-center *{max-height:none!important;overflow:visible!important;}";

  document.head.appendChild(s);

  var dee = document.getElementById('dee-command-center');
  if (dee && document.body.firstChild !== dee) {
    document.body.insertBefore(dee, document.body.firstChild);
  }
})();
</script>
"""

if "dee-command-center" in text:
    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("✅ Surgical clean fix applied")
PY

git add "$FILE"
git commit -m "Surgical fix: remove corrupted scripts + stable Dee override" || true
git push origin main || true
fly deploy
