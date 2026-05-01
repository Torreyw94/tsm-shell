#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
cp -f "$FILE" "$FILE.scrollfix.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

fix_css = r"""
<style id="honor-scroll-fix">
html, body {
  height: auto !important;
  min-height: 100% !important;
  overflow-x: hidden !important;
  overflow-y: auto !important;
}

body {
  display: block !important;
}

.wrap, .app, .shell, .main, .main-shell, .content, .content-shell, .dashboard, .portal-shell {
  height: auto !important;
  min-height: 0 !important;
  max-height: none !important;
  overflow: visible !important;
}

section, article, main, aside, .card, .panel, .pane, .tab-panel, .tab-content {
  max-height: none !important;
}

textarea, .console, .feed, .chat-log {
  max-height: none !important;
}

#out, #view, #war-room, #dee-live-output, #dee-live-inner {
  height: auto !important;
  min-height: 0 !important;
  max-height: none !important;
  overflow: visible !important;
}

[style*="100vh"], [style*="100dvh"], [style*="overflow:hidden"], [style*="max-height"] {
  max-height: none !important;
}

@media (min-width: 900px) {
  .grid, .grid2, .grid3, .grid4, .cols, .columns {
    align-items: start !important;
  }
}
</style>
"""

if 'id="honor-scroll-fix"' not in text:
    text = text.replace("</head>", fix_css + "\n</head>")

fix_js = r"""
<script id="honor-scroll-fix-js">
(function(){
  const selectors = [
    '.card', '.panel', '.pane', '.tab-panel', '.tab-content',
    '#out', '#view', '#war-room', '#dee-live-output', '#dee-live-inner',
    'main', 'section', 'article', '.content', '.dashboard'
  ];

  selectors.forEach(sel => {
    document.querySelectorAll(sel).forEach(el => {
      el.style.maxHeight = 'none';
      el.style.height = 'auto';
      el.style.overflow = 'visible';
    });
  });

  document.documentElement.style.overflowY = 'auto';
  document.body.style.overflowY = 'auto';
})();
</script>
"""

if 'id="honor-scroll-fix-js"' not in text:
    text = text.replace("</body>", fix_js + "\n</body>")

p.write_text(text, encoding="utf-8")
print("Applied honor portal scroll-height fix")
PY

git add "$FILE"
git commit -m "Fix honor portal scroll height and overflow traps" || true
git push origin main || true
fly deploy --local-only
