#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p backups/music_conversion
cp -f "$FILE" "backups/music_conversion/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

# -------------------------
# 1. Rename Copy → Export
# -------------------------
html = html.replace("Copy Full Version", "Export Final Version")

# -------------------------
# 2. Inject Conversion Block
# -------------------------
conversion_block = """
<div id="tsm-conversion-block" style="margin-top:16px;padding:14px;border:1px solid rgba(57,217,138,.3);border-radius:10px;background:rgba(57,217,138,.05)">
  <div style="font-size:12px;color:#39d98a;letter-spacing:.08em;margin-bottom:6px">
    SYSTEM NOTE
  </div>

  <div style="font-size:14px;font-weight:600;margin-bottom:8px">
    This version is stronger because:
  </div>

  <div style="font-size:12px;color:#a1a1aa;line-height:1.6">
    • Hook is more repeatable<br>
    • Structure flows into the chorus<br>
    • Emotional clarity improved
  </div>

  <div style="margin-top:12px;font-size:13px;font-weight:600">
    Most creators would stop here.
  </div>

  <button id="unlockBtn" style="margin-top:10px;width:100%;padding:10px;border-radius:6px;background:#39d98a;color:#000;font-weight:700;border:none;cursor:pointer">
    Unlock Full System →
  </button>
</div>
"""

# inject after export buttons section
if "tsm-conversion-block" not in html:
    html = re.sub(
        r'(Start New Song.*?</div>)',
        r'\1\n' + conversion_block,
        html,
        flags=re.S
    )

# -------------------------
# 3. Add unlock behavior
# -------------------------
script = """
<script id="tsm-unlock-flow">
(function(){
  if(window.__TSM_UNLOCK__) return;
  window.__TSM_UNLOCK__ = true;

  document.addEventListener("click", function(e){
    if(e.target && e.target.id === "unlockBtn"){
      const email = prompt("Enter your email to unlock full system:");
      if(!email) return;

      alert("Unlocked. Continue evolving your song.");

      // future: send to backend
      console.log("Captured lead:", email);
    }
  });
})();
</script>
"""

if "tsm-unlock-flow" not in html:
    html = html.replace("</body>", script + "\n</body>")

# -------------------------
# SAVE
# -------------------------
p.write_text(html, encoding="utf-8")
print("conversion block + unlock flow added")
PY

# -------------------------
# Commit + Deploy
# -------------------------
git add "$FILE"
git commit -m "Add conversion block + unlock flow to Music app" || true

fly deploy --local-only

echo
echo "OPEN:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=conversion"
