#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/demo-conductor.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_conductor_close
cp -f "$FILE" "backups/music_conductor_close/demo-conductor.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/music-command/demo-conductor.html")
html = p.read_text(encoding="utf-8", errors="ignore")

close_block = """
<div class="objectionBox" id="closeBox" style="border-color:rgba(34,197,94,.4);background:rgba(16,185,129,.08)">
  <h2 style="color:#86efac;">Final Close Script</h2>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    <b>Step 1 — Frame the outcome:</b><br/>
    “So what you just saw isn’t about generating lyrics.<br/>
    It’s about knowing which version is actually worth finishing.”
  </div>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    <b>Step 2 — Anchor value:</b><br/>
    “Most artists don’t get stuck starting…<br/>
    they get stuck deciding and finishing.<br/>
    This removes that loop.”
  </div>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    <b>Step 3 — Transition to offer:</b><br/>
    “There are a few ways to use this depending on how often you’re creating.”
  </div>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    <b>Step 4 — Direct ask:</b><br/>
    “Do you want access to this for your own songs?”
  </div>

  <div style="font-size:13px;line-height:1.6;margin-bottom:10px;">
    <b>If they hesitate:</b><br/>
    “No pressure — easiest way is just try it on one real track.<br/>
    If it helps, keep it. If not, you’ll know quickly.”
  </div>

  <div style="font-size:13px;line-height:1.6;">
    <b>If they say yes:</b><br/>
    “Perfect — I’ll unlock your access and show you how to use it on your own material.”
  </div>
</div>
"""

# insert near bottom before closing body
if "Final Close Script" not in html:
    html = html.replace("</body>", close_block + "\n</body>")

p.write_text(html, encoding="utf-8")
print("close script added to conductor")
PY

git add "$FILE"
git commit -m "Add closing script to Music demo conductor" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/demo-conductor.html?v=close"
