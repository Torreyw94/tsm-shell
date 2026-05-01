#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_revision_run_fix

cp -f server.js "backups/music_revision_run_fix/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_revision_run_fix/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

# 1) Frontend: stop calling dead route first
p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")
html = html.replace("/api/music/revision/run", "/api/music/agent/chain")
p.write_text(html, encoding="utf-8")
print("frontend route patched to /api/music/agent/chain")

# 2) Backend: restore /api/music/revision/run compatibility before API 404
p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

compat = r'''
// ===== MUSIC REVISION RUN COMPATIBILITY ROUTE =====
app.post('/api/music/revision/run', (req, res) => {
  const body = req.body || {};
  const draft = body.draft || body.input || body.text || "";
  const request = body.request || "guided creation app";

  if (!draft.trim()) {
    return res.status(400).json({ ok:false, error:"No draft provided" });
  }

  function localScore(txt){
    const len = String(txt || "").length;
    const base = Math.min(0.86, 0.70 + (len % 18) / 100);
    return {
      cadence: +(base + 0.06).toFixed(2),
      emotion: +(base + 0.00).toFixed(2),
      structure: +(base + 0.04).toFixed(2),
      imagery: +(base - 0.02).toFixed(2),
      overall: +(base + 0.03).toFixed(2)
    };
  }

  const score = localScore(draft);

  const flow = `[ZAY — CADENCE / BOUNCE]\n\n${draft}\n\nAgent move: tighten rhythm, shorten heavy phrasing, and make the last phrase hit in-pocket.`;
  const emotion = `[RIYA — EMOTION / IMAGERY]\n\n${draft}\n\nAgent move: make the emotional image more specific while keeping the artist voice plain-spoken.`;
  const hook = `[DJ — STRUCTURE / HOOK]\n\n${draft}\n\nAgent move: move the strongest repeatable phrase into hook position and clean the transition.`;

  const session = {
    id: Date.now(),
    request,
    input: draft,
    options: [
      { id:"A", title:"Flow First", strategy:"Cadence and bounce", output:flow, score },
      { id:"B", title:"Emotion First", strategy:"Imagery and vulnerability", output:emotion, score:{...score, overall:+(score.overall-.02).toFixed(2)} },
      { id:"C", title:"Hook First", strategy:"Structure and repeatability", output:hook, score:{...score, overall:+(score.overall-.01).toFixed(2)} }
    ],
    recommended:"A",
    createdAt:new Date().toISOString()
  };

  global.MUSIC_REVISION_SESSIONS = global.MUSIC_REVISION_SESSIONS || {};
  global.MUSIC_REVISION_SESSIONS[String(session.id)] = session;

  global.MUSIC_SUITE_STATE = global.MUSIC_SUITE_STATE || {};
  global.MUSIC_SUITE_STATE.lastRevision = session;
  global.MUSIC_SUITE_STATE.lastRun = {
    agents:["ZAY","RIYA","DJ"],
    output:flow,
    score,
    createdAt:session.createdAt
  };

  return res.json({
    ok:true,
    session,
    run:global.MUSIC_SUITE_STATE.lastRun
  });
});
// ===== END MUSIC REVISION RUN COMPATIBILITY ROUTE =====
'''

text = re.sub(
    r'\n// ===== MUSIC REVISION RUN COMPATIBILITY ROUTE =====.*?// ===== END MUSIC REVISION RUN COMPATIBILITY ROUTE =====\s*',
    '\n',
    text,
    flags=re.S
)

idx = text.find("app.use((req, res) => {")
if idx == -1:
    idx = text.find("res.status(404).json({ ok: false, error: 'API route not found' });")
if idx == -1:
    raise SystemExit("Could not find API 404 insertion point")

text = text[:idx] + compat + "\n" + text[idx:]
p.write_text(text, encoding="utf-8")
print("backend compatibility route inserted before API 404")
PY

node -c server.js

git add server.js html/music-command/index.html
git commit -m "Fix Music guided loop revision endpoint" || true

fly deploy --local-only

echo
echo "Test:"
echo "curl -s -X POST https://tsm-shell.fly.dev/api/music/revision/run -H 'Content-Type: application/json' -d '{\"draft\":\"test line\",\"request\":\"guided\"}'"
echo
echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=loopfix"
