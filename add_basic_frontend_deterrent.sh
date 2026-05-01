#!/usr/bin/env bash
set -euo pipefail

FILES=(
  html/music-command/index.html
  html/music-command/index2.html
  html/music-command/presentation-live.html
  html/music-command/marketing.html
)

STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p backups/frontend_deterrent

for FILE in "${FILES[@]}"; do
  [ -f "$FILE" ] || continue
  cp "$FILE" "backups/frontend_deterrent/$(basename $FILE).$STAMP.bak"

  python3 <<PY
from pathlib import Path
p = Path("$FILE")
html = p.read_text(encoding="utf-8", errors="ignore")

snippet = """
<script id="tsm-basic-deterrent">
(function(){
  // Block right-click
  document.addEventListener('contextmenu', e => e.preventDefault());

  // Block common DevTools keys
  document.addEventListener('keydown', function(e){
    if (
      e.key === "F12" ||
      (e.ctrlKey && e.shiftKey && ["I","J","C"].includes(e.key.toUpperCase())) ||
      (e.ctrlKey && e.key.toUpperCase() === "U")
    ){
      e.preventDefault();
    }
  });

  // Simple devtools open detection (weak)
  let devtools = false;
  setInterval(function(){
    const threshold = 160;
    if (window.outerWidth - window.innerWidth > threshold ||
        window.outerHeight - window.innerHeight > threshold) {
      if (!devtools) {
        devtools = true;
        console.warn("DevTools detected");
      }
    } else {
      devtools = false;
    }
  }, 1000);
})();
</script>
"""

if "tsm-basic-deterrent" not in html:
  html = html.replace("</body>", snippet + "\\n</body>")

p.write_text(html, encoding="utf-8")
print("patched", p)
PY
done

echo "Deterrent applied"
