#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
FILE="html/honor-portal/index.html"
cp "$FILE" "$FILE.delegate_ui.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# Replace alert with UI toast
text = text.replace(
    "alert(",
    "showToast("
)

# Inject toast system if missing
if "function showToast(" not in text:
    inject = """
<script>
function showToast(msg){
  let t = document.getElementById('tsm-toast');
  if (!t){
    t = document.createElement('div');
    t.id = 'tsm-toast';
    t.style.position = 'fixed';
    t.style.top = '20px';
    t.style.right = '20px';
    t.style.background = '#06121c';
    t.style.border = '1px solid rgba(0,255,163,.3)';
    t.style.color = '#00ffa3';
    t.style.padding = '12px 16px';
    t.style.borderRadius = '8px';
    t.style.fontFamily = 'monospace';
    t.style.zIndex = '9999';
    document.body.appendChild(t);
  }

  t.innerText = msg;
  t.style.opacity = '1';

  setTimeout(() => {
    t.style.opacity = '0';
  }, 2500);
}
</script>
"""
    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("toast UI installed")
PY

git add "$FILE"
git commit -m "Replace alert with command-center toast UI" || true
git push origin main || true
fly deploy --local-only
