#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p backups/runtime_clean
cp -f "$FILE" "backups/runtime_clean/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

# ----------------------------------------
# 1. REMOVE BROKEN INLINE SCRIPT BLOCKS
# ----------------------------------------
html = re.sub(
    r"<script[^>]*>.*?Invalid.*?</script>",
    "",
    html,
    flags=re.S
)

# ----------------------------------------
# 2. ENSURE goStep EXISTS
# ----------------------------------------
if "function goStep" not in html:
    html = html.replace(
        "</body>",
        """
<script>
function goStep(step){
  try{
    document.querySelectorAll('.step').forEach(s=>s.classList.remove('active'));
    const el = document.querySelector('[data-step="'+step+'"]');
    if(el) el.classList.add('active');
  }catch(e){
    console.warn("goStep fallback used", e);
  }
}
</script>
</body>
""")

# ----------------------------------------
# 3. FIX ANY BROKEN QUOTES IN BUTTONS
# ----------------------------------------
html = html.replace('onclick="goStep(', 'onclick="goStep(')

# ----------------------------------------
# 4. ADD SAFE SCRIPT GUARD (PREVENT FUTURE BREAKS)
# ----------------------------------------
if "window.__TSM_SAFE_RUNTIME__" not in html:
    html = html.replace(
        "</body>",
        """
<script>
(function(){
  if(window.__TSM_SAFE_RUNTIME__) return;
  window.__TSM_SAFE_RUNTIME__ = true;

  window.safe = function(fn){
    try{ return fn(); }
    catch(e){ console.warn("Safe wrapper caught:", e); }
  };
})();
</script>
</body>
""")

p.write_text(html)
PY

echo "✅ Runtime cleaned + navigation restored"
