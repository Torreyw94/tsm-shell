#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.cleanfinal.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. REMOVE stray style="" text nodes
text = re.sub(r'>\s*style=""\s*<', '><', text)
text = re.sub(r'\n\s*style=""\s*', '\n', text)

# 2. REMOVE any floating style="" at end of containers
text = re.sub(r'style=""\s*$', '', text, flags=re.MULTILINE)

# 3. EXTRA SAFETY: remove duplicated closing fragments
text = re.sub(r'</div>\s*style=""', '</div>', text)

p.write_text(text, encoding="utf-8")
print("✅ Cleaned stray style artifacts")
PY

git add "$FILE"
git commit -m "Clean stray style artifacts from Dee panel" || true
git push origin main || true
fly deploy
