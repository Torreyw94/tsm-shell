#!/usr/bin/env bash
set -euo pipefail

APP="/workspaces/tsm-shell"
cd "$APP"

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_suite_unified api

cp -f server.js "backups/music_suite_unified/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_suite_unified/index.$STAMP.bak" 2>/dev/null || true
cp -f html/music-command/index2.html "backups/music_suite_unified/index2.$STAMP.bak" 2>/dev/null || true
cp -f html/music-command/how-to-guide.html "backups/music_suite_unified/how-to-guide.$STAMP.bak" 2>/dev/null || true

python3 <<'PY'
from pathlib import Path
import re

root = Path("/workspaces/tsm-shell")
api = root / "api/music-suite.js"
server = root / "server.js"

api.write_text(r"""
module.exports = function(app){

  global.MUSIC_SUITE_STATE = global.MUSIC_SUITE_STATE || {
    updatedAt: new Date().toISOString(),
    artistsOnline: 12,
    releasesDropping: 3,
    monthlyStreams: "84M",
    revenueMTD: 847400,
    pipelineValue: 2400000,
    aiStatus: "online",
    activeWorkspace: "draft",
    agents: {
      zay: { name:"ZAY", role:"Cadence · Bounce · Live Feel", status:"online" },
      riya:{ name:"RIYA", role:"Word Choice · Imagery · Emotion", status:"online" },
      dj:  { name:"DJ", role:"Structure · Hook Placement · Transitions", status:"online" }
    },
    alerts: [
      { level:"urgent", title:"Artist K Contract", detail:"Renewal expires in 14 days" },
      { level:"high", title:"TikTok Viral Spike", detail:"Midnight Run has 8.2M uses" },
      { level:"high", title:"Royalty Dispute", detail:"Q4 2025 publisher discrepancy $28.4K" },
      { level:"ok", title:"Tour Confirmed", detail:"12 dates · $340K projected" }
    ],
    songs: [],
    actions: []
  };

  function state(){
    return global.MUSIC_SUITE_STATE;
  }

  app.get("/api/music/state", (_req, res) => {
    return res.json({ ok:true, state: state() });
  });

  app.post("/api/music/agent-pass", (req, res) => {
    const body = req.body || {};
    const draft = body.draft || "";
    const agent = body.agent || "full";
    const request = body.request || "Improve the draft";
    const priority = body.priority || "Catalog";

    const result = {
      ok:true,
      agent,
      priority,
      request,
      original:draft,
      output:
`AGENT PASS: ${agent.toUpperCase()}

Priority: ${priority}

Recommended direction:
1. Strengthen the emotional center of the first two lines.
2. Keep the plain-language pain, but sharpen the internal rhyme.
3. Build from conflict into motion so the hook feels inevitable.

Polished option:
Life been heavy, but I still move right through the fight
Every day a battle, still I turn the dark to light

Why it works:
The idea stays intact, but the phrasing becomes more musical, repeatable, and hook-ready.`,
      createdAt:new Date().toISOString()
    };

    state().actions.unshift({
      type:"agent-pass",
      agent,
      request,
      createdAt:result.createdAt
    });

    return res.json(result);
  });

  app.post("/api/music/strategy", (req, res) => {
    const prompt = (req.body && req.body.prompt) || "Build a music strategy";

    return res.json({
      ok:true,
      title:"Music Strategy Brief",
      prompt,
      answer:
`Best next move:

1. Use the viral signal first.
Turn the current attention into saves, follows, and repeatable audience capture.

2. Route the song through the agent stack.
ZAY checks cadence, RIYA sharpens imagery, DJ validates structure and hook placement.

3. Convert activity into revenue.
Prioritize sync, playlisting, short-form content, and release timing.

4. Save the final output into Song Bank.
This keeps the improved version connected to Artist DNA for future generation.`,
      createdAt:new Date().toISOString()
    });
  });

  app.post("/api/music/dna", (req, res) => {
    const body = req.body || {};
    const artist = body.artist || "Current Artist";
    const notes = body.notes || "";

    state().artistDNA = {
      artist,
      notes,
      updatedAt:new Date().toISOString(),
      status:"active"
    };

    return res.json({ ok:true, dna:state().artistDNA });
  });

  app.post("/api/music/song", (req, res) => {
    const body = req.body || {};
    const song = {
      id:Date.now(),
      title:body.title || "Untitled Song",
      draft:body.draft || "",
      status:"saved",
      createdAt:new Date().toISOString()
    };
    state().songs.unshift(song);
    return res.json({ ok:true, song, songs:state().songs });
  });

  app.get("/api/music/songs", (_req, res) => {
    return res.json({ ok:true, songs:state().songs });
  });

};
""", encoding="utf-8")

txt = server.read_text(encoding="utf-8", errors="ignore")
line = "require('./api/music-suite')(app);"
if line not in txt:
    # Must be before generic API 404 and before app.listen.
    markers = [
        "res.status(404).json({ ok: false, error: 'API route not found' });",
        'res.status(404).json({ ok:false, error:"API route not found" });',
        "app.listen("
    ]
    inserted = False
    for m in markers:
        i = txt.find(m)
        if i != -1:
            txt = txt[:i] + line + "\n\n" + txt[i:]
            inserted = True
            break
    if not inserted:
        txt += "\n" + line + "\n"
server.write_text(txt, encoding="utf-8")

# Inject frontend bridge into both Music app files.
bridge = r"""
<script>
window.MusicSuite = {
  async state(){
    return fetch('/api/music/state').then(r=>r.json());
  },
  async agentPass(payload){
    return fetch('/api/music/agent-pass',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify(payload||{})
    }).then(r=>r.json());
  },
  async strategy(prompt){
    return fetch('/api/music/strategy',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({prompt})
    }).then(r=>r.json());
  },
  async saveSong(payload){
    return fetch('/api/music/song',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify(payload||{})
    }).then(r=>r.json());
  }
};

async function musicSuiteBoot(){
  try{
    const data = await MusicSuite.state();
    console.log('Music Suite Online', data);
    const badge = document.querySelector('.pill.purple, .header-pills .pill, [id="keyStatus"]');
    if(badge && data.ok){
      if(badge.id === 'keyStatus'){
        badge.textContent = 'SUITE ONLINE';
        badge.className = 'key-status ok';
      }
    }
  }catch(e){
    console.warn('Music Suite backend unavailable', e);
  }
}

window.addEventListener('load', musicSuiteBoot);
</script>
"""

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = root / rel
    if p.exists():
        h = p.read_text(encoding="utf-8", errors="ignore")
        if "window.MusicSuite" not in h:
            h = h.replace("</body>", bridge + "\n</body>")
        p.write_text(h, encoding="utf-8")

print("Music suite unified backend + bridges applied")
PY

node -c api/music-suite.js
node -c server.js

git add api/music-suite.js server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Wire unified Music Command suite backend" || true
git push origin main || true
fly deploy --local-only

echo "DONE"
