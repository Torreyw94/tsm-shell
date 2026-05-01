#!/usr/bin/env bash
set -euo pipefail

STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p backups/auto_loop_story

for FILE in \
  html/music-command/how-to-guide.html \
  html/music-command/presentation-live.html \
  html/music-command/marketing.html
do
  cp -f "$FILE" "backups/auto_loop_story/$(basename $FILE).$STAMP.bak"
done

python3 <<'PY'
from pathlib import Path

def replace_block(path, old, new):
    txt = Path(path).read_text(encoding="utf-8", errors="ignore")
    if old in txt:
        txt = txt.replace(old, new)
    Path(path).write_text(txt, encoding="utf-8")

# ---------------------------
# HOW-TO GUIDE UPDATE
# ---------------------------
howto = "html/music-command/how-to-guide.html"

replace_block(
    howto,
    "Step-by-step processes for structuring songs",
    "Step-by-step process for generating, improving, and evolving songs automatically until they are release-ready."
)

replace_block(
    howto,
    "Build Your Artist DNA First",
    "Build Your Artist DNA First (This powers automatic improvement loops)"
)

# Add auto-loop section
txt = Path(howto).read_text()
if "AUTO LOOP" not in txt:
    txt += """
<section style="padding:40px;">
<h2 style="color:#ffd84d;">⚡ Auto Loop (New)</h2>
<p>The system now automatically improves your song through multiple passes:</p>
<ul>
<li>Run → Generate 3 options</li>
<li>Pick best direction</li>
<li>Auto-improve</li>
<li>Repeat until score threshold</li>
<li>Stop when release-ready</li>
</ul>
</section>
"""
Path(howto).write_text(txt)

# ---------------------------
# PRESENTATION UPDATE
# ---------------------------
pres = "html/music-command/presentation-live.html"

replace_block(
    pres,
    "Live Product Demo",
    "Live Auto-Evolution Demo"
)

replace_block(
    pres,
    "Generate options, score directions",
    "Generate → Improve → Auto-loop → Stop at optimal version"
)

# ---------------------------
# MARKETING UPDATE
# ---------------------------
marketing = "html/music-command/marketing.html"

replace_block(
    marketing,
    "AI songwriting decision engine",
    "AI songwriting evolution engine"
)

replace_block(
    marketing,
    "Generate options",
    "Generate → Improve → Iterate automatically"
)

# Add core positioning
txt = Path(marketing).read_text()
if "Write once. Let it evolve." not in txt:
    txt = txt.replace(
        "<body>",
        """<body>
<section style="padding:60px;text-align:center;">
<h1 style="font-size:3rem;color:#ffd84d;">Write once. Let it evolve.</h1>
<p style="font-size:1.2rem;color:#aaa;">
Your song doesn't stop at generation. It improves itself until it's ready.
</p>
</section>
"""
    )

Path(marketing).write_text(txt)

print("Auto-loop story upgrade applied.")
PY

git add html/music-command/*.html
git commit -m "Upgrade messaging for auto-loop evolution engine" || true

fly deploy --local-only

echo "DONE: Auto-loop messaging deployed"
