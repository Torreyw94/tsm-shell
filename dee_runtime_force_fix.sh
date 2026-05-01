#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.bak.$(date +%s)"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

inject = """
<script>
// ===== HARD OVERRIDE LAYOUT FIX =====
(function(){
  const style = document.createElement('style');
  style.innerHTML = `
    html, body {
      height: auto !important;
      min-height: 100% !important;
      overflow-y: auto !important;
      overflow-x: hidden !important;
      background: #050b14 !important;
    }

    body > *:not(#dee-command-center):not(script) {
      display: none !important;
    }

    #dee-command-center {
      display: block !important;
      position: relative !important;
      width: 100% !important;
      max-width: 1400px;
      margin: 0 auto;
    }

    #dee-command-center * {
      max-height: none !important;
      overflow: visible !important;
    }
  `;
  document.head.appendChild(style);

  // Force Dee to top
  const dee = document.getElementById('dee-command-center');
  if (dee && document.body.firstChild !== dee) {
    document.body.insertBefore(dee, document.body.firstChild);
  }
})();
</script>
"""

if "HARD OVERRIDE LAYOUT FIX" not in text:
    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("🔥 Runtime override injected (bulletproof)")
PY

git add "$FILE"
git commit -m "Runtime layout override (fix clipping + stacking permanently)" || true
git push origin main || true
fly deploy
