#!/usr/bin/env bash
set -e

FILE="/workspaces/tsm-shell/html/honor-portal/index.html"
cp "$FILE" "$FILE.runtimefix.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

if "window.__HONOR_RUNTIME__" not in text:
    inject = """

<script>
window.__HONOR_RUNTIME__ = true;

// ===== TAB SYSTEM (restored) =====
function showTab(tab){
  document.querySelectorAll('[data-tab]').forEach(el=>{
    el.style.display = (el.dataset.tab === tab) ? 'block' : 'none';
  });
}

// ===== BRIEFING HANDLER =====
function openBriefing(){
  const el = document.getElementById('dee-live-inner');
  if(el){
    el.innerHTML = '<div class="dee-narrative">Generating Team Briefing...</div>';
  }
}

// ===== SAFE FALLBACK FOR LEGACY BUTTONS =====
document.addEventListener('click', function(e){
  const btn = e.target.closest('button');

  if(!btn) return;

  if(btn.innerText.includes('BRIEF')){
    openBriefing();
  }
});

</script>
"""

    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("Runtime restored (tabs + briefing + safe handlers)")
PY

git add "$FILE"
git commit -m "Restore legacy runtime handlers (tabs + briefing)" || true
git push || true
fly deploy
