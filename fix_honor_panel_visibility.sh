#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"

cp "$FILE" "$FILE.bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/honor-portal/index.html")
text = p.read_text()

# Force panel to top of body
if '<body>' in text and 'honor-neural-panel' in text:
    parts = text.split('<body>')
    before = parts[0]
    after = parts[1]

    # remove existing panel
    import re
    after = re.sub(r'<div id="honor-neural-panel"[\s\S]*?</script>', '', after, count=1)

    # re-insert at top
    panel_start = text.find('<div id="honor-neural-panel"')
    panel_end = text.find('</script>', panel_start) + len('</script>')
    panel_block = text[panel_start:panel_end]

    new_after = panel_block + "\n\n" + after
    text = before + "<body>" + new_after

p.write_text(text)
print("Moved honor panel to top")
PY

git add "$FILE"
git commit -m "Fix honor panel visibility (move to top)" || true
git push origin main
fly deploy
