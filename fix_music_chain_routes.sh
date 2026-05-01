#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js backups/server.fix_music_chain_routes_$(date +%s).js

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Remove old multi-agent blocks and scattered chain/run routes
text = re.sub(r"\n// ===== MUSIC MULTI-AGENT ENGINE =====.*?// ===== END MUSIC MULTI-AGENT ENGINE =====\s*", "\n", text, flags=re.S)
text = re.sub(r"\napp\.post\('/api/music/agent/chain'.*?\n\}\);\s*", "\n", text, flags=re.S)
text = re.sub(r"\napp\.post\('/api/music/agent/run'.*?\n\}\);\s*", "\n", text, flags=re.S)
text = re.sub(r"\napp\.get\('/api/music/engine'.*?\n\}\);\s*", "\n", text, flags=re.S)
text = re.sub(r"\napp\.post\('/api/music/dna/learn'.*?\n\}\);\s*", "\n", text, flags=re.S)

block = r"""
// ===== MUSIC MULTI-AGENT ENGINE =====
global.MUSIC_ENGINE = global.MUSIC_ENGINE || {
  dna: {
    artist: "Current Artist",
    styleTerms: ["pain", "resilience", "late-night", "pressure", "bounce"],
    weights: { cadence: 0.88, emotion: 0.91, structure: 0.76, imagery: 0.82 },
    learnedSongs: []
  },
  runs: [],
  activity: []
};

function musicNow(){ return new Date().toISOString(); }

function scoreMusicDraft(text){
  const body = String(text || "");
  const lines = body.split(/\n+/).filter(Boolean).length;
  const lower = body.toLowerCase();
  const terms = global.MUSIC_ENGINE.dna.styleTerms || [];
  const matches = terms.filter(t => lower.includes(String(t).toLowerCase())).length;

  const cadence = Math.min(.99, .72 + (lines >= 2 ? .08 : 0) + (body.length > 60 ? .06 : 0));
  const emotion = Math.min(.99, .70 + matches * .04 + (lower.includes("fight") ? .07 : 0));
  const structure = Math.min(.99, .68 + (lines >= 4 ? .12 : .05));
  const imagery = Math.min(.99, .66 + matches * .04 + (lower.includes("light") ? .08 : 0));
  const overall = (cadence + emotion + structure + imagery) / 4;

  return {
    cadence: Number(cadence.toFixed(2)),
    emotion: Number(emotion.toFixed(2)),
    structure: Number(structure.toFixed(2)),
    imagery: Number(imagery.toFixed(2)),
    overall: Number(overall.toFixed(2))
  };
}

function agentPass(agent, draft, request){
  const a = String(agent || "ZAY").toUpperCase();
  const base = String(draft || "");

  if (a === "ZAY") {
    return "[ZAY — CADENCE / BOUNCE]\n\n" + base +
      "\n\nAgent move: tighten rhythm, shorten heavy phrasing, and make the last phrase hit in-pocket.";
  }

  if (a === "RIYA") {
    return "[RIYA — EMOTION / IMAGERY]\n\n" + base +
      "\n\nAgent move: make the emotional image more specific while keeping the artist voice plain-spoken.";
  }

  if (a === "DJ") {
    return "[DJ — STRUCTURE / HOOK]\n\n" + base +
      "\n\nAgent move: move the strongest repeatable phrase into hook position and clean the transition.";
  }

  return base;
}

function musicActivity(type, title, detail){
  const item = { id: Date.now(), type, title, detail, createdAt: musicNow() };
  global.MUSIC_ENGINE.activity.unshift(item);
  global.MUSIC_ENGINE.activity = global.MUSIC_ENGINE.activity.slice(0, 50);
  return item;
}

app.post('/api/music/agent/run', (req, res) => {
  const body = req.body || {};
  const agent = String(body.agent || "ZAY").toUpperCase();
  const draft = body.draft || "";
  const request = body.request || "Improve draft";
  const output = agentPass(agent, draft, request);
  const score = scoreMusicDraft(output);

  const run = {
    id: Date.now(),
    mode: "single",
    agent,
    request,
    input: draft,
    output,
    score,
    createdAt: musicNow()
  };

  global.MUSIC_ENGINE.runs.unshift(run);
  global.MUSIC_ENGINE.runs = global.MUSIC_ENGINE.runs.slice(0, 25);
  musicActivity("agent", agent + " pass complete", request);

  return res.json({ ok: true, run, engine: global.MUSIC_ENGINE });
});

app.post('/api/music/agent/chain', (req, res) => {
  const body = req.body || {};
  const draft = body.draft || "";
  const request = body.request || "Run full ZAY → RIYA → DJ chain";

  const zay = agentPass("ZAY", draft, request);
  const riya = agentPass("RIYA", zay, request);
  const dj = agentPass("DJ", riya, request);
  const score = scoreMusicDraft(dj);

  const run = {
    id: Date.now(),
    mode: "chain",
    agents: ["ZAY", "RIYA", "DJ"],
    request,
    input: draft,
    output: dj,
    pipeline: [
      { agent: "ZAY", output: zay, score: scoreMusicDraft(zay) },
      { agent: "RIYA", output: riya, score: scoreMusicDraft(riya) },
      { agent: "DJ", output: dj, score }
    ],
    score,
    createdAt: musicNow()
  };

  global.MUSIC_ENGINE.runs.unshift(run);
  global.MUSIC_ENGINE.runs = global.MUSIC_ENGINE.runs.slice(0, 25);
  global.MUSIC_ENGINE.dna.learnedSongs.unshift({
    title: body.title || "Working Draft",
    draft,
    output: dj,
    score,
    learnedAt: musicNow()
  });
  global.MUSIC_ENGINE.dna.learnedSongs = global.MUSIC_ENGINE.dna.learnedSongs.slice(0, 12);

  musicActivity("chain", "Multi-agent chain complete", "ZAY → RIYA → DJ score " + score.overall);

  return res.json({ ok: true, run, engine: global.MUSIC_ENGINE });
});

app.post('/api/music/dna/learn', (req, res) => {
  const body = req.body || {};
  const draft = body.draft || body.lyrics || "";
  const score = scoreMusicDraft(draft);

  global.MUSIC_ENGINE.dna.learnedSongs.unshift({
    id: Date.now(),
    title: body.title || "Learned Song",
    lyrics: draft,
    score,
    learnedAt: musicNow()
  });
  global.MUSIC_ENGINE.dna.learnedSongs = global.MUSIC_ENGINE.dna.learnedSongs.slice(0, 12);

  musicActivity("dna", "Artist DNA learned new song", body.title || "Learned Song");
  return res.json({ ok: true, dna: global.MUSIC_ENGINE.dna, score });
});

app.get('/api/music/engine', (_req, res) => {
  return res.json({ ok: true, engine: global.MUSIC_ENGINE });
});
// ===== END MUSIC MULTI-AGENT ENGINE =====

"""

# Insert before API 404 catchall
idx = text.find("app.use((req, res) => {")
if idx == -1:
    idx = text.find("res.status(404).json({ ok: false, error: 'API route not found' });")
if idx == -1:
    idx = text.find("app.listen(")
if idx == -1:
    text = text.rstrip() + "\n\n" + block
else:
    text = text[:idx] + block + text[idx:]

p.write_text(text, encoding="utf-8")
print("music run + chain routes registered before API 404")
PY

node -c server.js

git add server.js
git commit -m "Fix music multi-agent chain route registration" || true
git push origin main
fly deploy --local-only

echo "Testing chain endpoint..."
curl -s -X POST https://tsm-shell.fly.dev/api/music/agent/chain \
  -H "Content-Type: application/json" \
  -d '{"draft":"Life surrounded by wrong but trying to stay right is a fight\nEvery day a battle every night a new light","request":"full chain"}'
echo
