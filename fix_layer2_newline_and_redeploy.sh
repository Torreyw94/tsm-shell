#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

SERVER="server.js"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$SERVER" ] || { echo "Missing server.js"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$SERVER" "$BACKUP_DIR/server.js.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8")

# Fix the broken literal newline join:
text = text.replace("}).join('\\n');", "}).join('\\\\n');")

# Also fix the corrupted multiline variant:
text = text.replace("}).join('\n');", "}).join('\\\\n');")
text = text.replace("}).join('\r\n');", "}).join('\\\\n');")

# Catch the truly broken split form:
text = re.sub(r"\}\)\.join\('\s*\n\s*'\);", "}).join('\\\\n');", text)

p.write_text(text, encoding="utf-8")
print("patched server.js")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== SHOW DIFF =="
git diff -- server.js || true

echo "== COMMIT =="
git add server.js
git commit -m "Fix newline bug in Layer 2 root cause" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== RETEST =="
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/layer2 \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"system\":\"HonorHealth\",\"location\":\"Scottsdale - Shea\"}'"
