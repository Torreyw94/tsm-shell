#!/usr/bin/env bash
set -e

FILE="/workspaces/tsm-shell/html/honor-portal/index.html"
cp "$FILE" "$FILE.stabilized.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. REMOVE ALL INLINE onclick HANDLERS
text = re.sub(r'onclick="[^"]*"', '', text)

# 2. ADD DATA ATTRIBUTES FOR ACTION BUTTONS
text = text.replace("BUILD TEAM BRIEFING", '<span data-action="brief">BUILD TEAM BRIEFING</span>')
text = text.replace("PULL DENIAL RECOVERY", '<span data-action="recovery">PULL DENIAL RECOVERY</span>')
text = text.replace("PULL EXECUTIVE BRIEF", '<span data-action="brief">PULL EXECUTIVE BRIEF</span>')

# 3. ADD SINGLE GLOBAL EVENT SYSTEM
if "window.__HONOR_STABLE__" not in text:
    inject = """
<script>
window.__HONOR_STABLE__ = true;

document.addEventListener('click', function(e){
  const el = e.target.closest('[data-action]');
  if(!el) return;

  const action = el.dataset.action;
  const out = document.getElementById('dee-live-inner');

  if(!out) return;

  if(action === 'brief'){
    out.innerHTML = '<div class="dee-narrative">Generating Team Briefing...</div>';
  }

  if(action === 'recovery'){
    out.innerHTML = '<div class="dee-narrative">Running Denial Recovery...</div>';
  }
});
</script>
"""
    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("Portal stabilized (single event system active)")
PY

git add "$FILE"
git commit -m "Stabilize honor portal event system (remove inline onclick)" || true
git push || true
fly deploy
