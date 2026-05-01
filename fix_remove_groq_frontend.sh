#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p backups/remove_groq
cp -f "$FILE" "backups/remove_groq/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(errors="ignore")

# 1. Remove GROQ key line
html = re.sub(r"const GROQ_API_KEY\s*=.*?;", "", html)

# 2. Replace direct Groq API calls with backend route
html = re.sub(
    r"fetch\(\s*['\"]https://api\.groq\.com/openai/v1/chat/completions['\"].*?\)",
    "fetch('/api/music/chain', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({ prompt: userInput || '' }) })",
    html,
    flags=re.S
)

# 3. Clean any leftover Authorization headers
html = re.sub(r"'Authorization'.*?,", "", html)

p.write_text(html)
print("✅ Removed frontend Groq usage")
PY

echo "🚀 Done"
