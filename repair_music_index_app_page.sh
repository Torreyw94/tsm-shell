#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_index_repair
cp -f "$FILE" "backups/music_index_repair/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

# Remove protection overlays from APP page only
for sid in [
  "tsm-music-demo-protection",
  "tsm-demo-deal-closing-ui",
  "tsm-token-navigation-fix",
]:
    html = re.sub(
        rf'<script id="{sid}">.*?</script>',
        '',
        html,
        flags=re.S
    )

# Remove injected panel containers if they were written into body/static HTML
html = re.sub(
    r'<div[^>]+id=["\']tsm-demo-urgency-banner["\'][\s\S]*?</div>',
    '',
    html,
    flags=re.S
)
html = re.sub(
    r'<div[^>]+id=["\']tsm-demo-watermark["\'][\s\S]*?</div>',
    '',
    html,
    flags=re.S
)
html = re.sub(
    r'<div[^>]+id=["\']tsm-demo-upgrade-prompt["\'][\s\S]*?</div>',
    '',
    html,
    flags=re.S
)

# Add a safe token clear helper only; does not block app rendering.
safe = r'''
<script id="tsm-app-safe-token-clear">
(function(){
  const params = new URLSearchParams(location.search);
  if(params.get('clear_demo') === '1'){
    localStorage.removeItem('tsm_music_demo_token');
    history.replaceState({}, '', location.pathname + '?v=clean');
  }
})();
</script>
'''

html = re.sub(r'<script id="tsm-app-safe-token-clear">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", safe + "\n</body>") if "</body>" in html else html + "\n" + safe

p.write_text(html, encoding="utf-8")
print("repaired Music Command index app page")
PY

git add "$FILE"
git commit -m "Repair Music Command app page protection overlay" || true
fly deploy --local-only
