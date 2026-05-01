#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_multi_agent_loop

cp -f server.js "backups/music_multi_agent_loop/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_multi_agent_loop/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_multi_agent_loop/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

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

function musicScore(text, dna){
  const len = (text || "").length;
  const lines = (text || "").split(/\n+/).filter(Boolean).length;
  const terms = dna.styleTerms || [];
  const match = terms.filter(t => (text || "").toLowerCase().includes(String(t).toLowerCase())).length;

  const cadence = Math.min(0.99, 0.70 + (lines >= 2 ? 0.10 : 0) + (len > 60 ? 0.08 : 0) + (dna.weights.cadence || 0) * 0.08);
  const emotion = Math.min(0.99, 0.70 + match * 0.035 + (dna.weights.emotion || 0) * 0.12);
  const structure = Math.min(0.99, 0.68 + (lines >= 4 ? 0.12 : 0.05) + (dna.weights.structure || 0) * 0.12);
  const imagery = Math.min(0.99, 0.66 + match * 0.04 + (dna.weights.imagery || 0) * 0.13);
  const overall = (cadence + emotion + structure + imagery) / 4;

  return {
    cadence: Number(cadence.toFixed(2)),
    emotion: Number(emotion.toFixed(2)),
    structure: Number(structure.toFixed(2)),
    imagery: Number(imagery.toFixed(2)),
    overall: Number(overall.toFixed(2))
  };
}

function runMusicAgent(agent, draft, request, dna){
  const a = String(agent || "ZAY").toUpperCase();
  const base = draft || "";

  if(a === "ZAY"){
    return [
      "[ZAY — CADENCE / BOUNCE]",
      "",
      base,
      "",
      "Agent move: tighten the rhythm, shorten heavy phrasing, and make the line land harder in the pocket.",
      "Cadence note: push the strongest phrase to the end of the bar."
    ].join("\n");
  }

  if(a === "RIYA"){
    return [
      "[RIYA — EMOTION / IMAGERY]",
      "",
      base,
      "",
      "Agent move: sharpen emotional imagery while keeping the artist voice plain-spoken.",
      "Tone note: make pain specific, not generic."
    ].join("\n");
  }

  if(a === "DJ"){
    return [
      "[DJ — STRUCTURE / HOOK]",
      "",
      base,
      "",
      "Agent move: move the strongest repeatable phrase into hook position.",
      "Arrangement note: create a cleaner transition from verse pressure into hook release."
    ].join("\n");
  }

  return base;
}

function pushMusicEngineActivity(type, title, detail){
  const item = { id: Date.now(), type, title, detail, createdAt: musicNow() };
  global.MUSIC_ENGINE.activity.unshift(item);
  global.MUSIC_ENGINE.activity = global.MUSIC_ENGINE.activity.slice(0, 50);
  return item;
}

app.post('/api/music/agent/chain', (req, res) => {
  const body = req.body || {};
  const draft = body.draft || "";
  const request = body.request || "Run full ZAY → RIYA → DJ pass";
  const dna = global.MUSIC_ENGINE.dna;

  const zay = runMusicAgent("ZAY", draft, request, dna);
  const riya = runMusicAgent("RIYA", zay, request, dna);
  const dj = runMusicAgent("DJ", riya, request, dna);
  const score = musicScore(dj, dna);

  const run = {
    id: Date.now(),
    mode: "chain",
    request,
    agents: ["ZAY", "RIYA", "DJ"],
    input: draft,
    output: dj,
    pipeline: [
      { agent: "ZAY", output: zay, score: musicScore(zay, dna) },
      { agent: "RIYA", output: riya, score: musicScore(riya, dna) },
      { agent: "DJ", output: dj, score }
    ],
    score,
    createdAt: musicNow()
  };

  global.MUSIC_ENGINE.runs.unshift(run);
  global.MUSIC_ENGINE.runs = global.MUSIC_ENGINE.runs.slice(0, 25);
  global.MUSIC_ENGINE.dna.learnedSongs.unshift({ title: body.title || "Working Draft", draft, output: dj, score, learnedAt: musicNow() });
  global.MUSIC_ENGINE.dna.learnedSongs = global.MUSIC_ENGINE.dna.learnedSongs.slice(0, 12);

  pushMusicEngineActivity("chain", "Multi-agent chain complete", "ZAY → RIYA → DJ completed with score " + score.overall);

  return res.json({ ok: true, run, engine: global.MUSIC_ENGINE });
});

app.post('/api/music/agent/run', (req, res) => {
  const body = req.body || {};
  const agent = String(body.agent || "ZAY").toUpperCase();
  const draft = body.draft || "";
  const request = body.request || "Improve draft";
  const dna = global.MUSIC_ENGINE.dna;

  const output = runMusicAgent(agent, draft, request, dna);
  const score = musicScore(output, dna);

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
  pushMusicEngineActivity("agent", agent + " agent pass complete", request);

  return res.json({ ok: true, run, engine: global.MUSIC_ENGINE });
});

app.post('/api/music/dna/learn', (req, res) => {
  const body = req.body || {};
  const dna = global.MUSIC_ENGINE.dna;
  const draft = body.draft || body.lyrics || "";
  const score = musicScore(draft, dna);

  dna.artist = body.artist || dna.artist;
  dna.learnedSongs.unshift({
    id: Date.now(),
    title: body.title || "Learned Song",
    lyrics: draft,
    score,
    learnedAt: musicNow()
  });
  dna.learnedSongs = dna.learnedSongs.slice(0, 12);

  if((draft || "").toLowerCase().includes("fight")) dna.weights.emotion = 0.94;
  if((draft || "").toLowerCase().includes("light")) dna.weights.imagery = 0.90;
  if((draft || "").split(/\n+/).length >= 4) dna.weights.structure = 0.86;

  pushMusicEngineActivity("dna", "Artist DNA learned new song", body.title || "Learned Song");
  return res.json({ ok: true, dna, score });
});

app.get('/api/music/engine', (_req, res) => {
  return res.json({ ok: true, engine: global.MUSIC_ENGINE });
});
// ===== END MUSIC MULTI-AGENT ENGINE =====
"""

text = re.sub(
    r"// ===== MUSIC MULTI-AGENT ENGINE =====.*?// ===== END MUSIC MULTI-AGENT ENGINE =====\s*",
    "",
    text,
    flags=re.S
)

# Remove older single agent route so this engine owns /api/music/agent/run
text = re.sub(
    r"\n// ===== MUSIC AGENT ROUTE =====.*?// ===== END MUSIC AGENT ROUTE =====\s*",
    "\n",
    text,
    flags=re.S
)
text = re.sub(
    r"\napp\.post\('/api/music/agent/run'.*?\n\}\);\s*",
    "\n",
    text,
    flags=re.S
)

idx = text.find("res.status(404).json({ ok: false, error: 'API route not found' });")
if idx == -1:
    idx = text.find("app.use((req, res) => {")
if idx == -1:
    idx = text.find("app.listen(")
if idx == -1:
    text += "\n" + block
else:
    text = text[:idx] + block + "\n" + text[idx:]

p.write_text(text, encoding="utf-8")
print("multi-agent engine inserted")
PY

python3 <<'PY'
from pathlib import Path
import re

client = r"""
<script id="tsm-music-agent-ui-client">
(function(){
  if(window.__TSM_MUSIC_AGENT_UI__) return;
  window.__TSM_MUSIC_AGENT_UI__ = true;

  window.musicEngine = {
    runAgent(payload){
      return musicSafeFetch('/api/music/agent/run', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    runChain(payload){
      return musicSafeFetch('/api/music/agent/chain', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    learnDNA(payload){
      return musicSafeFetch('/api/music/dna/learn', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    state(){
      return musicSafeFetch('/api/music/engine');
    }
  };

  window.runFullMusicChainFromUI = async function(){
    const input =
      document.querySelector('textarea') ||
      document.getElementById('stratInput') ||
      document.querySelector('input[type="text"]');

    const draft = input ? (input.value || input.innerText || '') : '';

    const data = await musicEngine.runChain({
      title:'Working Draft',
      draft,
      request:'Run full ZAY RIYA DJ chain'
    });

    const out =
      document.getElementById('stratOutput') ||
      document.querySelector('[data-agent-output]');

    if(out && data.ok){
      out.style.display = 'block';
      out.textContent =
        data.run.output +
        '\n\nSCORE: ' + JSON.stringify(data.run.score, null, 2);
    }

    console.log('Full Music Chain Complete', data);
    return data;
  };
})();
</script>
"""

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")

    html = re.sub(
        r"<script id=\"tsm-music-agent-ui-client\">.*?</script>",
        "",
        html,
        flags=re.S
    )

    html = html.replace("</body>", client + "\n</body>") if "</body>" in html else html + "\n" + client
    p.write_text(html, encoding="utf-8")

print("agent UI client inserted")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Add multi-agent music engine with scoring and DNA memory" || true
git push origin main
fly deploy --local-only

echo "DONE"
