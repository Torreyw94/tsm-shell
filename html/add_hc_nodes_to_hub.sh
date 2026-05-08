#!/usr/bin/env bash
set -euo pipefail

SHELL="/workspaces/tsm-shell"
HTML="$SHELL/html"
HUB="$HTML/hub"

mkdir -p "$HTML" "$HUB"

echo "== 1. Copy hc-*.tsmatter.html files into hub app folders =="

for src in "$SHELL"/hc-*.tsmatter.html; do
  [ -f "$src" ] || continue

  base="$(basename "$src" .tsmatter.html)"   # hc-billing
  dest="$HTML/$base"
  mkdir -p "$dest"

  cp "$src" "$dest/index.html"

  # path-aware + backend rewrites
  sed -i "0,/<head>/s|<head>|<head><base href=\"/apps/$base/\">|" "$dest/index.html"
  sed -i 's|https://ai.tsmatter.com/ask|https://tsm-core.fly.dev/ask|g' "$dest/index.html"
  sed -i 's|https://ai.tsmatter.com/strategize|https://tsm-core.fly.dev/strategize|g' "$dest/index.html"
  sed -i 's|https://ai.tsmatter.com/api/node/|https://tsm-core.fly.dev/api/node/|g' "$dest/index.html"
  sed -i 's|https://strategist.tsmatter.com/ask|https://tsm-core.fly.dev/ask|g' "$dest/index.html"
  sed -i 's|https://strategist.tsmatter.com/strategize|https://tsm-core.fly.dev/strategize|g' "$dest/index.html"
  sed -i 's|ai.tsmatter.com|tsm-core.fly.dev|g' "$dest/index.html"
  sed -i 's|localhost:3200|tsm-core.fly.dev|g' "$dest/index.html"

  echo "✓ $base"
done

echo
echo "== 2. Rebuild hub list =="

APPS_JS=$(find "$HTML" -mindepth 1 -maxdepth 1 -type d ! -name hub ! -name default -printf "%f\n" | sort | sed "s/.*/'&'/" | paste -sd, -)

cat > "$HUB/index.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>TSM Hub</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:system-ui,sans-serif;background:#0b1120;color:#e5e7eb;display:grid;grid-template-columns:260px 1fr;height:100vh;overflow:hidden}
.sidebar{background:#111827;border-right:1px solid #1f2937;display:flex;flex-direction:column;overflow:hidden}
.header{padding:14px 16px;border-bottom:1px solid #1f2937;font-size:12px;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.08em}
.search{padding:10px 12px;border-bottom:1px solid #1f2937}
.search input{width:100%;font-size:13px;padding:8px 10px;border:1px solid #374151;border-radius:8px;outline:none;background:#0f172a;color:#e5e7eb}
.count{font-size:11px;color:#9ca3af;padding:8px 16px;border-bottom:1px solid #1f2937}
.list{overflow-y:auto;flex:1}
.item{padding:10px 16px;font-size:13px;cursor:pointer;display:flex;align-items:center;gap:8px;color:#d1d5db;border-bottom:1px solid #172033}
.item:hover{background:#0f172a}
.item.active{background:#1f2937;color:#a78bfa;border-left:3px solid #8b5cf6}
.dot{width:7px;height:7px;border-radius:50%;background:#22c55e;flex-shrink:0}
.main{display:flex;flex-direction:column;background:#020617}
.bar{padding:10px 16px;border-bottom:1px solid #1f2937;display:flex;align-items:center;gap:8px;background:#0b1220}
.url{flex:1;font-size:12px;padding:8px 10px;border:1px solid #334155;border-radius:8px;background:#0f172a;color:#94a3b8;font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
button{font-size:12px;padding:8px 12px;border:1px solid #334155;border-radius:8px;background:#111827;color:#e5e7eb;cursor:pointer}
button:hover{background:#1f2937}
iframe{flex:1;border:none;background:#fff}
.foot{padding:8px 16px;border-top:1px solid #1f2937;font-size:11px;color:#94a3b8;background:#0b1220;display:flex;gap:16px}
.live{color:#22c55e;font-weight:700}
</style>
</head>
<body>
<div class="sidebar">
  <div class="header">TSM Hub</div>
  <div class="search"><input id="q" placeholder="Search apps..." oninput="filterApps(this.value)"></div>
  <div class="count" id="count"></div>
  <div class="list" id="list"></div>
</div>
<div class="main">
  <div class="bar">
    <div class="url" id="url">select an app</div>
    <button onclick="reloadFrame()">⟳ Reload</button>
    <button onclick="openTab()">↗ Open</button>
  </div>
  <iframe id="frame" src="about:blank"></iframe>
  <div class="foot"><span class="live">● live</span><span id="active">none selected</span><span>tsm-shell hub</span></div>
</div>
<script>
const apps = [${APPS_JS}];

function render(list){
  document.getElementById('count').textContent = list.length + ' apps';
  document.getElementById('list').innerHTML = list.map(a =>
    '<div class="item" data-app="'+a+'" onclick="loadApp(\\''+a+'\\')"><span class="dot"></span>'+a+'</div>'
  ).join('');
}

function loadApp(name){
  document.querySelectorAll('.item').forEach(e=>e.classList.toggle('active',e.dataset.app===name));
  const url='/apps/'+name+'/';
  document.getElementById('url').textContent=url;
  document.getElementById('frame').src=url;
  document.getElementById('active').textContent=name;
}

function reloadFrame(){
  const f=document.getElementById('frame');
  if (f.src) f.src = f.src;
}

function openTab(){
  const f=document.getElementById('frame').src;
  if (f && f !== 'about:blank') window.open(f,'_blank');
}

function filterApps(q){
  const needle = (q || '').toLowerCase();
  render(apps.filter(a => a.toLowerCase().includes(needle)));
}

render(apps);
if (apps.length) loadApp(apps[0]);
</script>
</body>
</html>
HTMLEOF

echo
echo "== 3. Deploy updated hub =="
cd "$SHELL"
fly deploy --app tsm-shell --remote-only --ha=false

echo
echo "DONE"
echo "Open: https://tsm-shell.fly.dev/hub/?v=$(date +%s)"
