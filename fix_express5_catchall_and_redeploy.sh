#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

echo "== FIX EXPRESS 5 CATCH-ALL + REDEPLOY =="

[ -f server.js ] || { echo "Missing server.js"; exit 1; }
[ -f package.json ] || { echo "Missing package.json"; exit 1; }
[ -f fly.toml ] || { echo "Missing fly.toml"; exit 1; }

mkdir -p backups
cp -f server.js "backups/server.js.$(date +%Y%m%d-%H%M%S).bak"

python3 <<'PY'
from pathlib import Path
p = Path("server.js")
text = p.read_text(encoding="utf-8")

old = """app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'html', 'index.html'));
});"""

new = """app.use((req, res) => {
  res.sendFile(path.join(__dirname, 'html', 'index.html'));
});"""

if old in text:
    text = text.replace(old, new)
else:
    text = text.replace("app.get('*', (req, res) => {", "app.use((req, res) => {")

p.write_text(text, encoding="utf-8")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== GIT STATUS =="
git status --short

echo "== COMMIT =="
git add server.js
git commit -m "Fix Express 5 catch-all route" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== TEST COMMANDS =="
echo "curl https://tsm-shell.fly.dev/api/status"
echo "curl https://tsm-shell.fly.dev/api/hc/profiles"
echo "curl -X POST https://tsm-shell.fly.dev/api/hc/ask -H 'Content-Type: application/json' -d '{\"query\":\"what is the main issue\",\"system\":\"HonorHealth\"}'"
