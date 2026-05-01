#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.containerfix.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. FIX BROKEN CONTAINER (remove corrupted injection)
text = re.sub(
    r'id="dee-live-output".*?Dee Live Command Output</div>',
    '''
<div id="dee-live-output" style="
  margin-top:20px;
  padding:20px;
  border:1px solid rgba(0,255,163,.2);
  background:#06121c;
  color:#00ffa3;
  font-family:monospace;
  min-height:200px;
">
  <div style="font-weight:bold;margin-bottom:10px;">
    Dee Live Command Output
  </div>
</div>
''',
    text,
    flags=re.S
)

# 2. REMOVE ANY DUPLICATE INLINE STYLE STRINGS LEFT IN TEXT
text = re.sub(r'style="[^"]*"\s*style="[^"]*"', 'style=""', text)

# 3. CLEAN stray style text rendered as content
text = re.sub(r'style=" margin-top:.*?monospace; "', '', text)

p.write_text(text, encoding="utf-8")
print("✅ Dee container repaired cleanly")
PY

git add "$FILE"
git commit -m "Fix Dee container HTML structure" || true
git push origin main || true
fly deploy
