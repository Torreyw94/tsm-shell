#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.cleanui.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. REMOVE legacy onclick handlers
text = re.sub(r'onclick="(runPack|sendChat|showTab)\([^"]*\)"', '', text)

# 2. REWIRE buttons to quickAsk
text = re.sub(
    r'DRAFT CO-29 APPEAL',
    'DRAFT CO-29 APPEAL" onclick="quickAsk(\'draft co-29 appeal\')',
    text
)

text = re.sub(
    r'DENIAL REDUCTION PLAN',
    'DENIAL REDUCTION PLAN" onclick="quickAsk(\'denial reduction plan\')',
    text
)

text = re.sub(
    r'PAYER STRATEGY',
    'PAYER STRATEGY" onclick="quickAsk(\'payer strategy for Scottsdale Shea\')',
    text
)

text = re.sub(
    r'BOARD TALKING POINTS',
    'BOARD TALKING POINTS" onclick="quickAsk(\'board talking points for revenue cycle\')',
    text
)

# 3. REMOVE duplicate quickAsk errors if any inline scripts exist
text = re.sub(r'runPack\(|sendChat\(|showTab\(', 'void(', text)

p.write_text(text, encoding="utf-8")
print("✅ UI runtime cleaned + rewired to quickAsk")
PY

git add "$FILE"
git commit -m "Clean UI runtime + rewire to quickAsk" || true
git push origin main || true
fly deploy
