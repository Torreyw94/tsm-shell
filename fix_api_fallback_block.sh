#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

SERVER="server.js"
BACKUP="backups/server.js.$(date +%s).bak"

cp "$SERVER" "$BACKUP"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text()

# Replace fallback with API-safe version
text = re.sub(
    r"app\.use\(\(req,\s*res\)\s*=>\s*\{[^}]*res\.sendFile\([^}]*\)\s*;\s*\}\s*\)\s*;",
    """app.use((req, res, next) => {
  // 🔒 Do NOT intercept API routes
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ ok:false, error: 'API route not found' });
  }

  // 🌐 Only fallback for frontend routes
  return res.sendFile(path.join(__dirname, 'html', 'index.html'));
});""",
    text,
    flags=re.S
)

p.write_text(text)
print("✅ patched fallback safely")
PY

echo "== VERIFY =="
node -c server.js

echo "== COMMIT =="
git add server.js
git commit -m "Fix API fallback routing (prevent HTML override)" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== TEST AGAIN =="
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/rollup/brief -H \"Content-Type: application/json\" -d '{\"system\":\"HonorHealth\"}'"
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/alerts -H \"Content-Type: application/json\" -d '{\"system\":\"HonorHealth\"}'"

