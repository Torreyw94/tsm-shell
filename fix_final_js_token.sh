#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p backups/final_token_fix
cp -f "$FILE" "backups/final_token_fix/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

# ---------------------------------------
# 1. REMOVE NON-ASCII CHARACTERS (SAFE)
# ---------------------------------------
html = html.encode("ascii", "ignore").decode()

# ---------------------------------------
# 2. FIX BROKEN JS STRINGS
# (very common issue after patches)
# ---------------------------------------
html = re.sub(
    r'(".*?)(\n)(.*?")',
    lambda m: m.group(1) + " " + m.group(3),
    html,
    flags=re.S
)

# ---------------------------------------
# 3. REMOVE STRAY BACKTICKS
# ---------------------------------------
html = html.replace("`", "'")

# ---------------------------------------
# 4. SAFETY: CLOSE ANY OPEN coach( STRINGS
# ---------------------------------------
html = re.sub(
    r'coach\("([^"]*)$',
    r'coach("\1")',
    html
)

# ---------------------------------------
# 5. WRITE CLEAN FILE
# ---------------------------------------
p.write_text(html)

PY

echo "✅ Final JS token issue fixed"
