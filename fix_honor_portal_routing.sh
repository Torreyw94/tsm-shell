#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

SERVER="server.js"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$SERVER" ] || { echo "Missing $SERVER in $(pwd)"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$SERVER" "$BACKUP_DIR/server.js.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8")

# Ensure static serving uses html extension resolution
static_block = """app.use(express.static(__dirname, {
  extensions: ['html']
}));"""

# Replace older plain static if present
text = re.sub(
    r"app\.use\(express\.static\(__dirname\)\);",
    static_block,
    text
)

# Replace bad catch-all variants
patterns = [
    r"app\.use\(\(req,\s*res\)\s*=>\s*\{\s*res\.sendFile\(path\.join\(__dirname,\s*'html',\s*'index\.html'\)\);\s*\}\);",
    r"app\.use\(\(req,\s*res\)\s*=>\s*\{\s*res\.sendFile\(path\.join\(__dirname,\s*'index\.html'\)\);\s*\}\);",
    r"app\.get\('\*',\s*\(req,\s*res\)\s*=>\s*\{\s*res\.sendFile\(path\.join\(__dirname,\s*'html',\s*'index\.html'\)\);\s*\}\);",
]

replacement = """app.use((req, res) => {
  res.sendFile(path.join(__dirname, req.path), (err) => {
    if (err) {
      res.sendFile(path.join(__dirname, 'html', 'index.html'));
    }
  });
});"""

done = False
for pat in patterns:
    new_text, n = re.subn(pat, replacement, text, count=1, flags=re.DOTALL)
    if n:
        text = new_text
        done = True
        break

# If no known catch-all found, append a safe fallback after static serving
if not done:
    if replacement not in text:
        marker = static_block
        if marker in text:
            text = text.replace(marker, marker + "\n\n" + replacement, 1)
        else:
            text += "\n\n" + static_block + "\n\n" + replacement + "\n"

# If static block still missing, prepend it after express.json middleware
if static_block not in text:
    text = text.replace("app.use(express.json());", "app.use(express.json());\n\n" + static_block, 1)

p.write_text(text, encoding="utf-8")
print("patched server.js")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== SHOW ROUTING BLOCKS =="
grep -n "express.static\\|sendFile(path.join(__dirname, req.path))\\|html', 'index.html'" server.js || true

echo "== COMMIT =="
git add server.js
git commit -m "Fix routing for honor portal" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== TEST =="
echo "Open: https://tsm-shell.fly.dev/html/honor-portal/"
echo "Fallback root: https://tsm-shell.fly.dev/"
