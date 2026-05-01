#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

HUB="html/hub/index.html"
cp "$HUB" "backups/hub.index.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/hub/index.html")
text = p.read_text(encoding="utf-8")

# 1) Fix duplicated /html//html/ paths in hardcoded URLs if present
text = text.replace("/html//html/", "/html/")
text = text.replace("'/html//html/", "'/html/")
text = text.replace('"/html//html/', '"/html/')

# 2) Normalize load logic so local urls starting with /html/ are used as-is
pattern = r"""function\s+loadApp\s*\(el\)\s*\{[\s\S]*?\n\}"""
replacement = """function loadApp(el){
  const id = el.dataset.id;
  const name = el.dataset.name;
  const type = el.dataset.type;
  const live = el.dataset.live || null;

  currentId = id;
  currentUrl = id;
  currentName = name;
  currentLive = live;

  document.querySelectorAll('.item').forEach(e =>
    e.classList.toggle('active', e.dataset.id === id)
  );

  const urlBar = document.getElementById('url-bar');
  const frame = document.getElementById('frame');
  const activeLabel = document.getElementById('active-label');
  const liveBtn = document.getElementById('live-btn');
  const footType = document.getElementById('foot-type');

  activeLabel.textContent = name;

  if(type === 'cached' && live){
    liveBtn.classList.add('visible');
    liveBtn.title = 'Open live: ' + live;
  } else {
    liveBtn.classList.remove('visible');
  }

  footType.textContent = {local:'● local',cached:'◎ cached · live available'}[type] || '';
  footType.style.color = {local:'#1e40af',cached:'#166534'}[type] || '#374151';

  // local paths already rooted at /html/ should be used exactly as-is
  if (id.startsWith('/html/') || id.startsWith('http://') || id.startsWith('https://')) {
    urlBar.textContent = id;
    frame.src = id;
    return;
  }

  // fallback normalization for relative ids
  const normalized = '/' + id.replace(/^\\/+/, '');
  urlBar.textContent = normalized;
  frame.src = normalized;
}"""
text = re.sub(pattern, replacement, text, count=1)

p.write_text(text, encoding="utf-8")
print("patched html/hub/index.html")
PY

grep -n "/html//html/\|function loadApp" "$HUB" || true

git add "$HUB"
git commit -m "Fix hub arrow path handling for local demo apps" || true
git pull --rebase
git push
fly deploy
