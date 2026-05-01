#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/dee_clean
cp -f "$FILE" "backups/dee_clean/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. REMOVE any broken takeover CSS fragments
text = re.sub(r'/\* Hide EVERYTHING.*?\*/', '', text, flags=re.S)
text = re.sub(r'body > \*:not\(#dee-command-center\).*?\}', '', text, flags=re.S)

# 2. CLEAN FULLSCREEN CSS (fresh, correct)
clean_css = """
<style id="dee-clean-takeover">
html, body {
  height:auto !important;
  min-height:100% !important;
  overflow-y:auto !important;
  overflow-x:hidden !important;
  background:#050b14 !important;
}

/* Hide all legacy portal layers */
body > *:not(#dee-command-center):not(script):not(style) {
  display:none !important;
}

/* Ensure Dee is primary */
#dee-command-center {
  display:block !important;
  position:relative !important;
  width:100% !important;
  max-width:1400px;
  margin:0 auto;
}

/* Kill nested scroll traps */
#dee-command-center * {
  max-height:none !important;
  overflow:visible !important;
}
</style>
"""

# remove previous broken takeover blocks
text = re.sub(r'<style[^>]*dee[^>]*>.*?</style>', '', text, flags=re.S)

# inject clean one
text = text.replace("</body>", clean_css + "\n</body>")

# 3. FORCE Dee to top of DOM
text = text.replace(
    "anchor.parentElement.insertBefore(shell, anchor.nextSibling);",
    "document.body.insertBefore(shell, document.body.firstChild);"
)

p.write_text(text, encoding="utf-8")
print("✅ CLEAN Dee takeover applied")
PY

git add "$FILE"
git commit -m "Clean Dee war room takeover (fixed corrupted CSS)" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
