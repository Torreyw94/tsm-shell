#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.unhidebak.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# REMOVE the aggressive hide rule
text = re.sub(r'body>\*:not\(#dee-command-center\):not\(script\)\{display:none;?\}', '', text)

# Replace with SAFE version
inject = """
<script>
(function(){
  var style = document.createElement('style');
  style.innerHTML =
    "html,body{margin:0;padding:0;background:#050b14;overflow-y:auto;}" +

    /* Hide only known legacy layers */
    "#honor-neural-panel{display:none !important;}" +
    ".honor-top-strip{display:none !important;}" +
    ".portal-search{display:none !important;}" +

    /* Ensure Dee is visible */
    "#dee-command-center{display:block !important;position:relative;width:100%;max-width:1400px;margin:0 auto;}" +

    "#dee-command-center *{max-height:none;overflow:visible;}";

  document.head.appendChild(style);
})();
</script>
"""

# remove previous runtime override block
text = re.sub(r'<script>.*?Stable runtime override.*?</script>', '', text, flags=re.S)

# inject clean safe version
text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("✅ Fixed: Dee visible, legacy layers hidden safely")
PY

git add "$FILE"
git commit -m "Fix Dee visibility (remove aggressive hide rule)" || true
git push origin main || true
fly deploy
