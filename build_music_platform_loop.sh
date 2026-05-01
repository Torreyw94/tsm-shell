#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_platform_loop

cp -f server.js "backups/music_platform_loop/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_platform_loop/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_platform_loop/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

server = Path("server.js")
text = server.read_text(encoding="utf-8", errors="ignore")

block = r"""
// ===== MUSIC PLATFORM EXECUTION LOOP =====
global.MUSIC_PLATFORM = global.MUSIC_PLATFORM || {
  artistDNA: {
    status: "active",
    artist: "Current Artist",
    styleTerms: ["pain", "resilience", "late-night", "pressure", "bounce"],
    weights: { cadence: 0.88, emotion: 0.91, structure: 0.76, imagery: 0.82 },
    learnedSongs: []
  },
  agentRuns: [],
  activity: []
};

function musicStamp(){ return new Date().toISOString(); }

function pushMusicActivity(type, title, detail){
  const item = { id: Date.now(), type, title, detail, createdAt: musicStamp() };
  global.MUSIC_PLATFORM.activity.unshift(item);
  global.MUSIC_PLATFORM.activity = global.MUSIC_PLATFORM.activity.slice(0, 50);
  return item;
}

app.post('/api/music/dna/save', (req, res) => {
  const body = req.body || {};
  const dna = global.MUSIC_PLATFORM.artistDNA;
  dna.artist = body.artist || dna.artist;
  dna.notes = body.notes || dna.notes || "";
  dna.styleTerms = Array.isArray(body.styleTerms) ? body.styleTerms : dna.styleTerms;
  dna.weights = Object.assign({}, dna.weights, body.weights || {});
  dna.updatedAt = musicStamp();
  pushMusicActivity("dna", "Artist DNA updated", dna.artist + " DNA memory refreshed");
  return res.json({ ok:true, dna });
});

app.post('/api/music/song/learn', (req, res) => {
  const body = req.body || {};
  const song = {
    id: Date.now(),
    title: body.title || "Untitled Song",
    lyrics: body.lyrics || body.draft || "",
    tags: body.tags || [],
    learnedAt: musicStamp()
  };

  global.MUSIC_PLATFORM.artistDNA.learnedSongs.unshift(song);
  global.MUSIC_PLATFORM.artistDNA.learnedSongs =
    global.MUSIC_PLATFORM.artistDNA.learnedSongs.slice(0, 12);

  const lyric = song.lyrics.toLowerCase();
  if (lyric.includes("fight") || lyric.includes("pain")) global.MUSIC_PLATFORM.artistDNA.weights.emotion = 0.94;
  if (lyric.includes("night") || lyric.includes("light")) global.MUSIC_PLATFORM.artistDNA.weights.imagery = 0.88;
  if (lyric.split("\n").length >= 4) global.MUSIC_PLATFORM.artistDNA.weights.structure = 0.84;

  pushMusicActivity("learn", "Song learned into DNA", song.title);
  return res.json({ ok:true, song, dna:global.MUSIC_PLATFORM.artistDNA });
});

app.post('/api/music/agent/run', (req, res) => {
  const body = req.body || {};
  const agent = (body.agent || "ZAY").toUpperCase();
  const draft = body.draft || "";
  const request = body.request || "Improve this song";
  const dna = global.MUSIC_PLATFORM.artistDNA;

  const agentMap = {
    ZAY: "Cadence, bounce, pocket, and live feel",
    RIYA: "Word choice, imagery, vulnerability, and emotional tone",
    DJ: "Structure, hook placement, transitions, and replay value"
  };

  const output = [
    agent + " AGENT PASS",
    "",
    "Focus: " + (agentMap[agent] || "Full song improvement"),
    "DNA Match: " + Math.round(((dna.weights.cadence + dna.weights.emotion + dna.weights.structure + dna.weights.imagery) / 4) * 100) + "%",
    "",
    "Recommended move:",
    agent === "ZAY" ? "Tighten the bounce and make the second line land harder." :
    agent === "RIYA" ? "Make the emotional image more specific while keeping the plain-spoken voice." :
    agent === "DJ" ? "Move the strongest phrase into hook position and create a cleaner transition." :
    "Run ZAY, RIYA, then DJ for a complete pass.",
    "",
    "Reworked draft:",
    draft
      ? draft.replace("trying to stay right is a fight", "tryna stay right in the middle of the fight")
             .replace("Every day's a battle", "Every day a battle")
      : "Paste a draft first, then run the agent pass."
  ].join("\\n");

  const run = {
    id: Date.now(),
    agent,
    request,
    output,
    createdAt: musicStamp()
  };

  global.MUSIC_PLATFORM.agentRuns.unshift(run);
  global.MUSIC_PLATFORM.agentRuns = global.MUSIC_PLATFORM.agentRuns.slice(0, 25);

  pushMusicActivity("agent", agent + " completed agent pass", request);
  return res.json({ ok:true, run, platform:global.MUSIC_PLATFORM });
});

app.get('/api/music/activity', (_req, res) => {
  return res.json({ ok:true, activity:global.MUSIC_PLATFORM.activity, platform:global.MUSIC_PLATFORM });
});

app.get('/api/music/platform', (_req, res) => {
  return res.json({ ok:true, platform:global.MUSIC_PLATFORM });
});
// ===== END MUSIC PLATFORM EXECUTION LOOP =====
"""

text = re.sub(
  r"// ===== MUSIC PLATFORM EXECUTION LOOP =====.*?// ===== END MUSIC PLATFORM EXECUTION LOOP =====\s*",
  "",
  text,
  flags=re.S
)

marker = "res.status(404).json({ ok: false, error: 'API route not found' });"
idx = text.find(marker)
if idx == -1:
    idx = text.find("app.listen(")
if idx == -1:
    text += "\n" + block
else:
    text = text[:idx] + block + "\n" + text[idx:]

server.write_text(text, encoding="utf-8")
print("Music platform API loop inserted")
PY

python3 <<'PY'
from pathlib import Path

client = r"""
<script id="tsm-music-platform-client">
(function(){
  if(window.__TSM_MUSIC_PLATFORM_CLIENT__) return;
  window.__TSM_MUSIC_PLATFORM_CLIENT__ = true;

  window.musicPlatform = {
    dnaSave(payload){
      return musicSafeFetch('/api/music/dna/save', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload||{})
      });
    },
    learnSong(payload){
      return musicSafeFetch('/api/music/song/learn', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload||{})
      });
    },
    runAgent(payload){
      return musicSafeFetch('/api/music/agent/run', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload||{})
      });
    },
    activity(){
      return musicSafeFetch('/api/music/activity');
    },
    platform(){
      return musicSafeFetch('/api/music/platform');
    }
  };

  window.runMusicAgentFromUI = async function(agent){
    const draftEl =
      document.querySelector('textarea') ||
      document.querySelector('[contenteditable="true"]');

    const draft = draftEl ? (draftEl.value || draftEl.innerText || '') : '';
    const data = await musicPlatform.runAgent({
      agent: agent || 'ZAY',
      draft,
      request: 'Improve draft using Artist DNA'
    });

    console.log('Agent Run Complete', data);

    const output =
      document.getElementById('stratOutput') ||
      document.querySelector('[data-agent-output]');

    if(output && data.ok){
      output.style.display = 'block';
      output.textContent = data.run.output;
    }

    return data;
  };

  window.learnCurrentDraft = async function(){
    const draftEl = document.querySelector('textarea');
    const draft = draftEl ? draftEl.value : '';
    const data = await musicPlatform.learnSong({
      title: 'Working Draft',
      lyrics: draft,
      tags: ['working', 'artist-dna']
    });
    console.log('Draft learned into DNA', data);
    return data;
  };
})();
</script>
"""

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")
    html = html.replace('<script id="tsm-music-platform-client">', '<script id="old-tsm-music-platform-client">')
    if "</body>" in html:
        html = html.replace("</body>", client + "\n</body>")
    else:
        html += "\n" + client
    p.write_text(html, encoding="utf-8")

print("Music platform client injected")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Build Music Platform agent execution and Artist DNA memory loop" || true
git push origin main
fly deploy --local-only

echo "DONE"
