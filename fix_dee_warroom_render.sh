#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.warroomfix.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. REMOVE "Loading..." war room block
text = re.sub(
    r'Dee War Room Live.*?Loading\.\.\.',
    'Dee War Room Live',
    text,
    flags=re.S
)

# 2. ADD REAL RENDER TARGET
if "id=\"dee-live-output\"" not in text:
    text = text.replace(
        "Dee War Room Live",
        """Dee War Room Live
<div id="dee-live-output" style="
  margin-top:12px;
  padding:16px;
  border:1px solid rgba(0,255,163,.15);
  background:#07111b;
  color:#00ffa3;
  font-family:monospace;
"></div>
"""
    )

# 3. MODIFY quickAsk render target
text = text.replace(
    "document.body",
    "document.getElementById('dee-live-output') || document.body"
)

p.write_text(text, encoding="utf-8")
print("✅ Dee War Room now wired to real strategist output")
PY

git add "$FILE"
git commit -m "Wire Dee war room to strategist output" || true
git push origin main || true
fly deploy
