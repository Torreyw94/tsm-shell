#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/demo-conductor.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_conductor_objections
cp -f "$FILE" "backups/music_conductor_objections/demo-conductor.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/music-command/demo-conductor.html")
html = p.read_text(encoding="utf-8", errors="ignore")

css = """
<style id="objection-css">
.objectionBox{
  margin-top:14px;
  border:1px solid rgba(251,113,133,.28);
  background:rgba(127,29,29,.12);
  border-radius:14px;
  padding:14px;
}
.objectionBox h2{
  font-size:15px;
  margin:0 0 8px;
  color:#fecdd3;
}
.objBtn{
  width:100%;
  margin:6px 0;
  text-align:left;
  border:1px solid rgba(255,255,255,.12);
  background:rgba(255,255,255,.055);
  color:#fff;
  padding:10px 12px;
  border-radius:10px;
  cursor:pointer;
  font-weight:800;
}
.objBtn:hover{border-color:rgba(251,113,133,.6)}
.objAnswer{
  margin-top:10px;
  white-space:pre-wrap;
  font-family:var(--mono);
  font-size:12px;
  line-height:1.55;
  color:#e5e7eb;
}
</style>
"""

if "objection-css" not in html:
    html = html.replace("</head>", css + "\n</head>")

box = """
<div class="objectionBox">
  <h2>Live Objection Handler</h2>
  <button class="objBtn" onclick="showObj('chatgpt')">“I already use ChatGPT.”</button>
  <button class="objBtn" onclick="showObj('need')">“I don’t need this.”</button>
  <button class="objBtn" onclick="showObj('price')">“How much is it?”</button>
  <button class="objBtn" onclick="showObj('quality')">“Can AI really judge music?”</button>
  <pre class="objAnswer" id="objAnswer">Click an objection if it comes up during the demo.</pre>
</div>
"""

if "Live Objection Handler" not in html:
    html = html.replace('<div class="actionBox">', box + '\n\n    <div class="actionBox">')

js = """
<script id="objection-js">
const objectionAnswers = {
  chatgpt: `Totally — ChatGPT is great for generating ideas.

The difference is this is not built around one prompt and one answer.

This is built around a music workflow:
generate options, score directions, pick the strongest version, improve it again, and track whether the song is getting better.

So ChatGPT gives you output.
This gives you a process.`,

  need: `That makes sense — not every writer needs help starting.

Where this usually helps is after you already have something.

The hard part is:
which version is stronger,
what should change next,
and whether it is ready.

This is less about replacing your creativity and more about removing the second-guessing loop.`,

  price: `It depends on how often you are writing.

The simple way to think about it is:
Free shows how the system thinks.
Creator Mode is for regular writing.
Studio Mode is for serious release work.
Label Mode is for catalog-building and teams.

If it helps finish even one stronger release faster, it usually pays for itself.`,

  quality: `It is not pretending to be the final judge of taste.

It gives directional signals:
cadence, emotion, structure, imagery, and hook strength.

You still make the creative decision.
The system just gives you better options and a clearer next move.`
};

function showObj(key){
  const el = document.getElementById('objAnswer');
  if(el) el.textContent = objectionAnswers[key] || '';
}
</script>
"""

if "objection-js" not in html:
    html = html.replace("</body>", js + "\n</body>")

p.write_text(html, encoding="utf-8")
print("objection handler added to conductor")
PY

git add "$FILE"
git commit -m "Add objection handling to Music demo conductor" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/demo-conductor.html?v=objections"
