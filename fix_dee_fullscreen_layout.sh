#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/dee_fullscreen_layout
cp -f "$FILE" "backups/dee_fullscreen_layout/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1) Remove max-height clipping on war room
text = text.replace(
    "max-height:calc(100vh - 150px);",
    "max-height:none;"
)

# 2) Ensure full-page scrolling is allowed
if "html, body{" not in text:
    text = text.replace(
        "<style>",
        """<style>
html, body{
  height:auto !important;
  min-height:100% !important;
  overflow-y:auto !important;
  overflow-x:hidden !important;
}
body{
  background:#050b14;
}
""",
        1
    )

# 3) Make Dee command center fully visible and not nested-clipped
text = text.replace(
    "#dee-command-center{",
    """#dee-command-center{
  position:relative;
  z-index:20;
  width:100%;
"""
)

# 4) Remove internal scroll from major panels so whole app can be seen naturally
text = text.replace(
    "max-height:420px;",
    "max-height:none;"
)
text = text.replace(
    "overflow:auto;",
    "overflow:visible;"
)

# 5) Keep alerts/action/ranking readable without micro-scroll
text = text.replace(
    ".wr-panel short",
    ".wr-panel short"
)

# 6) Hide the old duplicated top strip/banner blocks that are still showing above war room
hide_css = """
/* Hide old duplicated portal strips above war room */
body > div:first-of-type,
#honor-neural-panel,
.honor-top-strip,
.honor-search,
.honor-command-search,
.portal-search,
.portal-topbar {
  display:none !important;
}
"""
if hide_css not in text:
    text = text.replace("</style>", hide_css + "\n</style>", 1)

# 7) If the war room is being inserted after old content, move it to the top of body
old_anchor = """    const anchor =
      document.querySelector('#honor-neural-panel') ||
      document.querySelector('[data-email="brief"]')?.parentElement?.parentElement ||
      document.body;

    anchor.parentElement.insertBefore(shell, anchor.nextSibling);"""

new_anchor = """    const anchor = document.body;
    anchor.insertBefore(shell, anchor.firstChild);"""

text = text.replace(old_anchor, new_anchor)

# 8) Add a stronger top margin reset so the war room starts immediately
text = text.replace(
    "margin:16px 0 24px;",
    "margin:0 0 24px;"
)

p.write_text(text, encoding="utf-8")
print("Applied Dee fullscreen layout fix")
PY

git add "$FILE"
git commit -m "Fix Dee portal fullscreen layout and remove clipping" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
