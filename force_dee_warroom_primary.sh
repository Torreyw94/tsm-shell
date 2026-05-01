#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.deeprimary.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. FORCE clear existing output injection logic
text = re.sub(
    r'const target = .*?;',
    "const target = document.getElementById('dee-live-output');",
    text
)

# 2. ENSURE container is visible and prominent
text = text.replace(
    'id="dee-live-output"',
    '''id="dee-live-output" style="
        margin-top:20px;
        padding:20px;
        border:1px solid rgba(0,255,163,.2);
        background:#06121c;
        color:#00ffa3;
        font-family:monospace;
        min-height:200px;
    "'''
)

# 3. ADD header so it's obvious
if "Dee Live Command Output" not in text:
    text = text.replace(
        'id="dee-live-output"',
        'id="dee-live-output"><div style="font-weight:bold;margin-bottom:10px;">Dee Live Command Output</div>'
    )

p.write_text(text, encoding="utf-8")
print("✅ Dee war room forced as primary output surface")
PY

git add "$FILE"
git commit -m "Force Dee war room as primary render surface" || true
git push origin main || true
fly deploy
