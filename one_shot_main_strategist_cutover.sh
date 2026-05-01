#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/main_strategist_cutover

# Backups
cp -a html/strategist "backups/main_strategist_cutover/strategist.$STAMP.bak" 2>/dev/null || true
cp -f html/hub/index.html "backups/main_strategist_cutover/hub.index.$STAMP.bak" 2>/dev/null || true
cp -f html/honor-portal/index.html "backups/main_strategist_cutover/honor-portal.index.$STAMP.bak" 2>/dev/null || true
cp -f server.js "backups/main_strategist_cutover/server.$STAMP.bak" 2>/dev/null || true

python3 <<'PY'
from pathlib import Path
import shutil
import re

root = Path("/workspaces/tsm-shell")
strategist_dir = root / "html" / "strategist"
main_dir = root / "html" / "main-strategist"
hub_file = root / "html" / "hub" / "index.html"
honor_file = root / "html" / "honor-portal" / "index.html"
server_file = root / "server.js"

# 1) Rename/copy current strategist folder to main-strategist
if strategist_dir.exists():
    if main_dir.exists():
        shutil.rmtree(main_dir)
    shutil.copytree(strategist_dir, main_dir)

# 2) Recreate placeholder /html/strategist/ for future global strategist so old path doesn't 404 badly
strategist_dir.mkdir(parents=True, exist_ok=True)
placeholder = strategist_dir / "index.html"
if not placeholder.exists() or "Global Strategist Reserved" not in placeholder.read_text(encoding="utf-8", errors="ignore"):
    placeholder.write_text("""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TSM Strategist Routing Notice</title>
  <style>
    body{margin:0;background:#07101b;color:#d9e7ff;font-family:Arial,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh}
    .wrap{max-width:760px;padding:28px;border:1px solid rgba(255,255,255,.1);background:rgba(255,255,255,.03);border-radius:16px}
    h1{margin-top:0;color:#8fb3ff}
    a{color:#9fd0ff}
  </style>
</head>
<body>
  <div class="wrap">
    <h1>Global Strategist Reserved</h1>
    <p>The healthcare production strategist has moved to <a href="/html/main-strategist/">/html/main-strategist/</a>.</p>
    <p>This path is reserved for a future cross-domain strategist.</p>
  </div>
</body>
</html>
""", encoding="utf-8")

# 3) Update Hub links
if hub_file.exists():
    hub = hub_file.read_text(encoding="utf-8", errors="ignore")
    hub = hub.replace("/html/strategist/", "/html/main-strategist/")
    hub = hub.replace("url:'/html/strategist/'", "url:'/html/main-strategist/'")
    hub = hub.replace('url:"/html/strategist/"', 'url:"/html/main-strategist/"')
    hub_file.write_text(hub, encoding="utf-8")

# 4) Update Honor Portal references
if honor_file.exists():
    honor = honor_file.read_text(encoding="utf-8", errors="ignore")
    honor = honor.replace("/html/strategist/", "/html/main-strategist/")
    honor_file.write_text(honor, encoding="utf-8")

# 5) Add static route for main-strategist if missing
if server_file.exists():
    server = server_file.read_text(encoding="utf-8", errors="ignore")
    if "app.use('/html/main-strategist'" not in server:
        marker = "app.use('/html/hc-strategist', express.static(path.join(__dirname, 'html', 'hc-strategist')));"
        insert = marker + "\napp.use('/html/main-strategist', express.static(path.join(__dirname, 'html', 'main-strategist')));"
        if marker in server:
            server = server.replace(marker, insert, 1)
        else:
            m = re.search(r"app\.use\('/html/healthcare'.*?\);\n", server)
            if m:
                idx = m.end()
                server = server[:idx] + "app.use('/html/main-strategist', express.static(path.join(__dirname, 'html', 'main-strategist')));\n" + server[idx:]
        server_file.write_text(server, encoding="utf-8")

print("Applied main-strategist cutover")
PY

echo "== VERIFY FILES =="
ls -lah html/main-strategist/index.html html/strategist/index.html html/hub/index.html html/honor-portal/index.html

echo "== VERIFY LINKS =="
grep -n "/html/main-strategist/" html/hub/index.html html/honor-portal/index.html || true
grep -n "app.use('/html/main-strategist'" server.js || true

echo "== SYNTAX CHECK =="
node -c server.js

echo "== COMMIT =="
git add html/main-strategist html/strategist html/hub/index.html html/honor-portal/index.html server.js
git commit -m "Cut over healthcare strategist to /html/main-strategist" || true

echo "== PUSH =="
git pull --rebase origin main || true
git push origin main || true

echo "== DEPLOY =="
fly deploy

echo "== TEST =="
curl -I https://tsm-shell.fly.dev/html/main-strategist/
curl -I https://tsm-shell.fly.dev/html/hub/
curl -I https://tsm-shell.fly.dev/html/honor-portal/
