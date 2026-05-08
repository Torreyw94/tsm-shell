#!/bin/bash
set -e

echo "🏗️  Building TSM Hub..."

# ── 1. COLLECT ALL APP NAMES FROM HTML FOLDERS ──────────────────────────────
APPS=$(ls html/)

# ── 2. GENERATE HUB HTML ────────────────────────────────────────────────────
mkdir -p html/hub

cat > html/hub/index.html << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TSM Hub</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:system-ui,sans-serif;background:#f5f5f5;display:grid;grid-template-columns:220px 1fr;height:100vh;overflow:hidden}
  .sidebar{background:#fff;border-right:1px solid #e5e5e5;display:flex;flex-direction:column}
  .sidebar-header{padding:14px 16px;border-bottom:1px solid #e5e5e5;font-size:13px;font-weight:600;color:#888;letter-spacing:.05em;text-transform:uppercase}
  .search{padding:10px 12px;border-bottom:1px solid #e5e5e5}
  .search input{width:100%;font-size:13px;padding:6px 10px;border:1px solid #e0e0e0;border-radius:6px;outline:none}
  .search input:focus{border-color:#7F77DD}
  .app-list{overflow-y:auto;flex:1}
  .app-item{padding:9px 16px;font-size:13px;cursor:pointer;display:flex;align-items:center;gap:8px;color:#555;border-bottom:1px solid #f0f0f0}
  .app-item:hover{background:#f9f9f9;color:#111}
  .app-item.active{background:#fafafa;color:#111;font-weight:500;border-left:2px solid #7F77DD}
  .dot{width:7px;height:7px;border-radius:50%;background:#1D9E75;flex-shrink:0}
  .main{display:flex;flex-direction:column}
  .topbar{padding:10px 16px;border-bottom:1px solid #e5e5e5;display:flex;align-items:center;gap:10px;background:#fff}
  .url-bar{flex:1;font-size:12px;padding:6px 10px;border:1px solid #e0e0e0;border-radius:6px;background:#f9f9f9;color:#666;font-family:monospace}
  .btn{font-size:12px;padding:6px 12px;border:1px solid #e0e0e0;border-radius:6px;background:#fff;color:#333;cursor:pointer}
  .btn:hover{background:#f5f5f5}
  iframe{flex:1;border:none;background:#fff}
  .status-bar{padding:8px 16px;border-top:1px solid #e5e5e5;display:flex;gap:16px;font-size:11px;color:#888;background:#fff}
  .badge{display:inline-flex;align-items:center;gap:4px;padding:2px 8px;border-radius:6px;background:#EAF3DE;color:#3B6D11}
</style>
</head>
<body>
<div class="sidebar">
  <div class="sidebar-header">TSM Hub</div>
  <div class="search"><input id="search" placeholder="Search apps..." oninput="filterApps(this.value)"></div>
  <div class="app-list" id="appList"></div>
</div>
<div class="main">
  <div class="topbar">
    <div class="url-bar" id="urlBar">/preview/...</div>
    <button class="btn" onclick="reloadFrame()">⟳ Reload</button>
    <button class="btn" onclick="openExternal()">↗ Open</button>
  </div>
  <iframe id="preview" src="about:blank"></iframe>
  <div class="status-bar">
    <span class="badge">● live</span>
    <span>1 machine · tsm-shell.internal:8080</span>
    <span id="activeApp"></span>
  </div>
</div>
<script>
const apps = [$(ls html/ | grep -v hub | sed "s/.*/'&'/" | tr '\n' ',' | sed 's/,$//')]

function renderApps(list) {
  const el = document.getElementById('appList')
  el.innerHTML = list.map(a => \`<div class="app-item" onclick="loadApp('\${a}')">\<span class="dot"></span>\${a}</div>\`).join('')
}

function loadApp(name) {
  document.querySelectorAll('.app-item').forEach(el => {
    el.classList.toggle('active', el.textContent.trim() === name)
  })
  const url = '/preview/' + name
  document.getElementById('urlBar').textContent = url
  document.getElementById('preview').src = url
  document.getElementById('activeApp').textContent = name
}

function reloadFrame() {
  const f = document.getElementById('preview')
  f.src = f.src
}

function openExternal() {
  window.open(document.getElementById('preview').src, '_blank')
}

function filterApps(q) {
  renderApps(apps.filter(a => a.includes(q.toLowerCase())))
}

renderApps(apps)
if(apps.length) loadApp(apps[0])
</script>
</body>
</html>
HTMLEOF

echo "  ✅ Hub HTML generated with ${#APPS[@]} apps"

# ── 3. ADD HUB + PROXY BLOCKS TO NGINX.CONF ─────────────────────────────────
# Remove old hub block if exists
sed -i '/## HUB START ##/,/## HUB END ##/d' nginx.conf

# Find closing brace of http block and insert before it
cat >> nginx.conf << 'NGINXEOF'
## HUB START ##
    server {
        listen 8080;
        server_name hub.* _;

        location / {
            root /usr/share/nginx/html/hub;
            index index.html;
        }

        location ~ ^/preview/(.+)$ {
            proxy_pass http://127.0.0.1:8080;
            proxy_set_header Host "$1.tsmatter.com";
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
## HUB END ##
NGINXEOF

echo "  ✅ Nginx hub block added"

# ── 4. VALIDATE & DEPLOY ─────────────────────────────────────────────────────
docker run --rm -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf nginx:alpine nginx -t
fly deploy --app tsm-shell --remote-only

echo ""
echo "✅ Hub live at http://tsm-shell.internal/hub"
echo "   or tunnel locally: fly proxy 8080 --app tsm-shell"
echo "   then open: http://localhost:8080/hub"
