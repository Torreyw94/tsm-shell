#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

HUB="html/index.html"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$HUB" ] || { echo "Missing $HUB in $(pwd)"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$HUB" "$BACKUP_DIR/index.html.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/index.html")
text = p.read_text(encoding="utf-8")

# 1) Promote core healthcare apps to local/live demo paths
replacements = {
    r"\{ sector:'Healthcare', name:'Healthcare Command',\s*type:'local',\s*url:'[^']*' \}":
        "{ sector:'Healthcare', name:'Healthcare Command', type:'local', url:'/html/healthcare/' }",
    r"\{ sector:'Healthcare', name:'HC Strategist',\s*type:'cached',\s*url:'[^']*',\s*liveUrl:'[^']*' \}":
        "{ sector:'Healthcare', name:'HC Strategist', type:'local', url:'/html/hc-strategist/' }",
    r"\{ sector:'Healthcare', name:'Honor Portal',\s*type:'local',\s*url:'[^']*' \}":
        "{ sector:'Healthcare', name:'Honor Portal', type:'local', url:'/html/honor-portal/' }",
    r"\{ sector:'Enterprise', name:'Suite Builder',\s*type:'local',\s*url:'[^']*' \}":
        "{ sector:'Enterprise', name:'Suite Builder', type:'local', url:'/html/suite-builder.html' }",
}

for pat, repl in replacements.items():
    text = re.sub(pat, repl, text)

# 2) Start in Healthcare for demo mode
text = re.sub(
    r"let activeFilter='[^']+'",
    "let activeFilter='Healthcare'",
    text,
    count=1
)

# 3) Make cached apps open live externally by default, instead of stale snapshot in frame
loadapp_pattern = r"""function loadApp\(el\)\{[\s\S]*?document\.getElementById\('frame'\)\.src=id;\n\}"""
loadapp_replacement = """function loadApp(el){
  const id=el.dataset.id, name=el.dataset.name, type=el.dataset.type, live=el.dataset.live||null;
  currentId=id; currentUrl=id; currentName=name; currentLive=live;

  document.querySelectorAll('.item').forEach(e=>e.classList.toggle('active',e.dataset.id===id));
  document.getElementById('url-bar').textContent=id;
  document.getElementById('active-label').textContent=name;

  const liveBtn=document.getElementById('live-btn');
  if(type==='cached'&&live){liveBtn.classList.add('visible');liveBtn.title='Open live: '+live;}
  else{liveBtn.classList.remove('visible');}

  const footType=document.getElementById('foot-type');
  footType.textContent={local:'● local',cached:'◎ cached · live available'}[type]||'';
  footType.style.color={local:'#1e40af',cached:'#166534'}[type]||'#374151';

  if(type==='cached' && live){
    document.getElementById('frame').src=live;
    document.getElementById('url-bar').textContent=live;
    currentUrl=live;
    return;
  }

  document.getElementById('frame').src=id;
}"""
text = re.sub(loadapp_pattern, loadapp_replacement, text, count=1)

# 4) Autoload HC Strategist instead of first random local app
autoload_pattern = r"""buildSectorTabs\(\);\s*render\(\);\s*const first=ALL_APPS\.find\(a=>a\.type==='local'\);\s*if\(first\)\{[\s\S]*?\n\}"""
autoload_replacement = """buildSectorTabs();
render();
const first =
  ALL_APPS.find(a=>a.url==='/html/hc-strategist/') ||
  ALL_APPS.find(a=>a.url==='/html/healthcare/') ||
  ALL_APPS.find(a=>a.type==='local');

if(first){
  currentId=currentUrl=first.url;currentName=first.name;currentLive=first.liveUrl||null;
  document.getElementById('url-bar').textContent=first.url;
  document.getElementById('frame').src=first.url;
  document.getElementById('active-label').textContent=first.name;
  document.getElementById('foot-type').textContent='● local';
  document.getElementById('foot-type').style.color='#1e40af';
  setTimeout(()=>{document.querySelectorAll('.item').forEach(el=>
    el.classList.toggle('active',el.dataset.id===first.url));},50);
}"""
text = re.sub(autoload_pattern, autoload_replacement, text, count=1)

# 5) Move the 4 demo-critical apps to the top of their sectors
all_apps_match = re.search(r"const ALL_APPS = \[(.*?)\n\];", text, re.S)
if all_apps_match:
    block = all_apps_match.group(1)
    lines = [ln for ln in block.splitlines()]

    def extract_entry(name):
        pat = re.compile(rf".*name:'{re.escape(name)}'.*")
        for i, ln in enumerate(lines):
            if pat.match(ln.strip()):
                return i, ln
        return None, None

    wanted = [
        "Healthcare Command",
        "HC Strategist",
        "Honor Portal",
        "Suite Builder",
    ]

    extracted = []
    remaining = []
    for ln in lines:
        if any(f"name:'{w}'" in ln for w in wanted):
            extracted.append(ln)
        else:
            remaining.append(ln)

    # Rebuild with healthcare promoted near healthcare section and suite builder left in enterprise section
    # Simple, safe approach: prepend promoted lines after const ALL_APPS = [
    new_block = "\n".join(extracted + remaining)
    text = text[:all_apps_match.start(1)] + new_block + text[all_apps_match.end(1):]

p.write_text(text, encoding="utf-8")
print("patched html/index.html")
PY

echo "== REVIEW DEMO TARGETS =="
grep -n "Healthcare Command\|HC Strategist\|Honor Portal\|Suite Builder\|let activeFilter=" "$HUB" || true

echo "== COMMIT =="
git add "$HUB"
git commit -m "Convert hub to demo mode and promote best apps" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "Open:"
echo "https://tsm-shell.fly.dev/"
echo
echo "Expected demo priority:"
echo "1) HC Strategist"
echo "2) Healthcare Command"
echo "3) Honor Portal"
echo "4) Suite Builder"
