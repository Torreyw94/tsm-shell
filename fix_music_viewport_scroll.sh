#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_viewport_scroll

cp -f html/music-command/index.html "backups/music_viewport_scroll/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_viewport_scroll/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

patch = r'''
<style id="tsm-music-viewport-scroll-fix">
  html, body {
    height: 100%;
    overflow: hidden !important;
  }

  body {
    margin: 0;
  }

  .app,
  .shell,
  .layout,
  .main,
  main {
    min-height: 0 !important;
  }

  main,
  .main,
  #mainContent,
  .content,
  .workspace,
  .page,
  .view {
    max-height: calc(100vh - 92px) !important;
    overflow-y: auto !important;
    overflow-x: hidden !important;
    padding-bottom: 120px !important;
    scroll-behavior: smooth;
  }

  #music-evolution-panel,
  #music-commerce-panel,
  #music-pricing-panel {
    max-width: 100% !important;
    box-sizing: border-box !important;
  }

  #music-evolution-panel {
    margin-top: 10px !important;
  }

  #music-commerce-panel,
  #music-pricing-panel {
    margin-bottom: 90px !important;
  }

  body::-webkit-scrollbar {
    display: none;
  }

  main::-webkit-scrollbar,
  .main::-webkit-scrollbar,
  #mainContent::-webkit-scrollbar,
  .content::-webkit-scrollbar,
  .workspace::-webkit-scrollbar,
  .page::-webkit-scrollbar,
  .view::-webkit-scrollbar {
    width: 8px;
  }

  main::-webkit-scrollbar-thumb,
  .main::-webkit-scrollbar-thumb,
  #mainContent::-webkit-scrollbar-thumb,
  .content::-webkit-scrollbar-thumb,
  .workspace::-webkit-scrollbar-thumb,
  .page::-webkit-scrollbar-thumb,
  .view::-webkit-scrollbar-thumb {
    background: rgba(168,85,247,.45);
    border-radius: 999px;
  }
</style>
'''

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")

    html = re.sub(
        r'<style id="tsm-music-viewport-scroll-fix">.*?</style>',
        '',
        html,
        flags=re.S
    )

    if "</head>" in html:
        html = html.replace("</head>", patch + "\n</head>")
    else:
        html = patch + "\n" + html

    p.write_text(html, encoding="utf-8")

print("music viewport scroll fix applied")
PY

git add html/music-command/index.html html/music-command/index2.html
git commit -m "Fix Music Command viewport scroll height" || true
git push origin main
fly deploy --local-only
