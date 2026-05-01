#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/dee_full_takeover
cp -f "$FILE" "backups/dee_full_takeover/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. Force Dee war room to be the only visible app layer
force_css = """
<style>
html, body {
  height:auto !important;
  min-height:100% !important;
  overflow-y:auto !important;
  overflow-x:hidden !important;
  background:#050b14 !important;
}

/* Hide EVERYTHING except Dee war room */
body > *:not(#dee-command-center):not(script):not(style) {
  display:none !important;
}

/* Ensure Dee fills full screen */
#dee-command-center {
  display:block !important;
  position:relative !important;
  width:100% !important;
  max-width:1400px;
  margin:0 auto;
}

/* Remove all internal scroll traps */
#dee-command-center * {
  max-height:none !important;
  overflow:visible !important;
}

/* Fix header spacing */
#dee-command-center > div:first-child {
  margin-top:0 !important;
}
</style>
"""

if "dee_full_takeover" not in text:
    text = text.replace("</body>", force_css + "\n</body>", 1)

# 2. Ensure Dee is inserted at very top of body
text = text.replace(
    "anchor.parentElement.insertBefore(shell, anchor.nextSibling);",
    "document.body.insertBefore(shell, document.body.firstChild);"
)

p.write_text(text, encoding="utf-8")
print("🔥 Dee war room FULL takeover applied")
PY

git add "$FILE"
git commit -m "Force Dee war room full-screen takeover" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
