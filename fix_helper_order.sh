#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js "backups/server.js.reorder.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Extract helper functions
helpers = []

patterns = [
    r"function filterHCState[\s\S]*?\n\}",
    r"function buildLayer2Summary[\s\S]*?\n\}",
    r"function buildHCBrief[\s\S]*?\n\}",
    r"function buildStrategistSystemPosture[\s\S]*?\n\}"
]

for pat in patterns:
    m = re.search(pat, text)
    if m:
        helpers.append(m.group(0))
        text = text.replace(m.group(0), "")

# Remove duplicate whitespace
text = re.sub(r"\n{3,}", "\n\n", text)

# Insert helpers BEFORE first app route
m = re.search(r"\napp\.(get|post|use)\(", text)
if not m:
    raise SystemExit("Could not find route insertion point")

idx = m.start()

helper_block = "\n\n// ===== TSM CORE HELPERS =====\n\n" + "\n\n".join(helpers) + "\n\n"

text = text[:idx] + helper_block + text[idx:]

p.write_text(text, encoding="utf-8")

print("✅ Reordered helpers ABOVE all routes")
PY

node -c server.js

git add server.js
git commit -m "Fix helper order (move all to top)" || true
git pull --rebase origin main || true
git push origin main || true

fly deploy
