#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_revision_mode

cp -f server.js "backups/music_revision_mode/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_revision_mode/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_revision_mode/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

block = r"""
// ===== MUSIC REVISION MODE =====
global.MUSIC_REVISIONS = global.MUSIC_REVISIONS || {
  sessions: [],
  selected: null
};

function revisionScoreBoost(score, i){
  return {
    cadence: Number(Math.min(.99, score.cadence + (i * .01)).toFixed(2)),
    emotion: Number(Math.min(.99, score.emotion + (i === 1 ? .03 : .01)).toFixed(2)),
    structure: Number(Math.min(.99, score.structure + (i === 2 ? .04 : .01)).toFixed(2)),
    imagery: Number(Math.min(.99, score.imagery + (i === 1 ? .04 : .01)).toFixed(2)),
    overall: 0
  };
}

function finalizeScore(s){
  s.overall = Number(((s.cadence + s.emotion + s.structure + s.imagery) / 4).toFixed(2));
  return s;
}

app.post('/api/music/revision/generate', (req, res) => {
  const body = req.body || {};
  const draft = body.draft || "";
  const request = body.request || "Generate 3 revision options";

  const baseA = agentPass("ZAY", draft, request);
  const baseB = agentPass("RIYA", draft, request);
  const baseC = agentPass("DJ", draft, request);

  const variants = [
    {
      id: "A",
      title: "Option A · Flow First",
      strategy: "Best for cadence, bounce, and live feel.",
      output: baseA,
      score: finalizeScore(revisionScoreBoost(scoreMusicDraft(baseA), 0))
    },
    {
      id: "B",
      title: "Option B · Emotion First",
      strategy: "Best for imagery, vulnerability, and artist voice.",
      output: baseB,
      score: finalizeScore(revisionScoreBoost(scoreMusicDraft(baseB), 1))
    },
    {
      id: "C",
      title: "Option C · Hook First",
      strategy: "Best for structure, repeatability, and release readiness.",
      output: baseC,
      score: finalizeScore(revisionScoreBoost(scoreMusicDraft(baseC), 2))
    }
  ];

  variants.sort((a,b) => b.score.overall - a.score.overall);

  const session = {
    id: Date.now(),
    request,
    input: draft,
    options: variants,
    recommended: variants[0].id,
    createdAt: new Date().toISOString()
  };

  global.MUSIC_REVISIONS.sessions.unshift(session);
  global.MUSIC_REVISIONS.sessions = global.MUSIC_REVISIONS.sessions.slice(0, 20);

  if (typeof musicActivity === "function") {
    musicActivity("revision", "Revision mode generated 3 options", "Recommended " + variants[0].title);
  }

  return res.json({ ok:true, session });
});

app.post('/api/music/revision/select', (req, res) => {
  const body = req.body || {};
  const sessionId = body.sessionId;
  const optionId = body.optionId;

  const session = global.MUSIC_REVISIONS.sessions.find(s => String(s.id) === String(sessionId));
  if (!session) return res.status(404).json({ ok:false, error:"Revision session not found" });

  const option = session.options.find(o => o.id === optionId);
  if (!option) return res.status(404).json({ ok:false, error:"Revision option not found" });

  global.MUSIC_REVISIONS.selected = {
    sessionId,
    optionId,
    option,
    selectedAt: new Date().toISOString()
  };

  if (global.MUSIC_ENGINE && global.MUSIC_ENGINE.dna) {
    global.MUSIC_ENGINE.dna.learnedSongs.unshift({
      title: "Selected Revision " + optionId,
      draft: session.input,
      output: option.output,
      score: option.score,
      learnedAt: new Date().toISOString()
    });
    global.MUSIC_ENGINE.dna.learnedSongs = global.MUSIC_ENGINE.dna.learnedSongs.slice(0, 12);
  }

  return res.json({ ok:true, selected:global.MUSIC_REVISIONS.selected });
});

app.get('/api/music/revision/state', (_req, res) => {
  return res.json({ ok:true, revisions:global.MUSIC_REVISIONS });
});
// ===== END MUSIC REVISION MODE =====
"""

text = re.sub(
    r"// ===== MUSIC REVISION MODE =====.*?// ===== END MUSIC REVISION MODE =====\s*",
    "",
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
print("revision API inserted")
PY

python3 <<'PY'
from pathlib import Path
import re

client = r"""
<script id="tsm-music-revision-ui">
(function(){
  if(window.__TSM_MUSIC_REVISION_UI__) return;
  window.__TSM_MUSIC_REVISION_UI__ = true;

  window.musicRevision = {
    generate(payload){
      return musicSafeFetch('/api/music/revision/generate', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    select(payload){
      return musicSafeFetch('/api/music/revision/select', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    state(){
      return musicSafeFetch('/api/music/revision/state');
    }
  };

  function revisionHtml(session){
    return `
      <div style="margin-top:14px;padding:12px;border:1px solid rgba(168,85,247,.35);background:rgba(6,13,24,.96);border-radius:6px">
        <div style="font-family:var(--mono);font-size:.58rem;color:var(--purple);letter-spacing:.12em;text-transform:uppercase;margin-bottom:10px">
          Revision Mode · Recommended ${session.recommended}
        </div>
        <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px">
          ${session.options.map(o => `
            <div style="border:1px solid rgba(168,85,247,.18);padding:10px;border-radius:4px;background:rgba(8,15,31,.75)">
              <div style="font-family:var(--head);font-size:.72rem;color:var(--text);margin-bottom:4px">${o.title}</div>
              <div style="font-size:.72rem;color:var(--text2);line-height:1.4;margin-bottom:8px">${o.strategy}</div>
              <div style="font-family:var(--mono);font-size:.55rem;color:var(--green);margin-bottom:8px">
                Overall ${o.score.overall} · Cad ${o.score.cadence} · Emo ${o.score.emotion} · Str ${o.score.structure}
              </div>
              <pre style="white-space:pre-wrap;max-height:180px;overflow:auto;font-size:.7rem;color:var(--text2);background:var(--bg3);padding:8px;border-radius:3px">${o.output}</pre>
              <button class="btn btn-purple" style="margin-top:8px;width:100%;justify-content:center"
                onclick="selectRevisionOption('${session.id}','${o.id}')">
                Pick ${o.id}
              </button>
            </div>
          `).join('')}
        </div>
      </div>
    `;
  }

  window.runRevisionMode = async function(){
    const input =
      document.querySelector('textarea') ||
      document.getElementById('stratInput') ||
      document.querySelector('input[type="text"]');

    const draft = input ? (input.value || input.innerText || '') : '';

    const data = await musicRevision.generate({
      draft,
      request:'Generate 3 revision options'
    });

    const out =
      document.getElementById('stratOutput') ||
      document.querySelector('[data-agent-output]') ||
      document.getElementById('mainContent');

    if(out && data.ok){
      out.style.display = 'block';
      out.innerHTML = revisionHtml(data.session);
    }

    console.log('Revision Mode Ready', data);
    return data;
  };

  window.selectRevisionOption = async function(sessionId, optionId){
    const data = await musicRevision.select({ sessionId, optionId });
    console.log('Revision Selected', data);
    alert('Selected revision ' + optionId + ' and saved into Artist DNA');
    return data;
  };
})();
</script>
"""

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")

    html = re.sub(
        r"<script id=\"tsm-music-revision-ui\">.*?</script>",
        "",
        html,
        flags=re.S
    )

    # Add button near strategy quick actions if possible
    if "runRevisionMode()" not in html:
        html = html.replace(
            "</body>",
            client + "\n</body>"
        )
    else:
        html = html.replace("</body>", client + "\n</body>")

    p.write_text(html, encoding="utf-8")

print("revision UI client inserted")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Add Music Revision Mode with 3 options and scoring panel" || true
git push origin main
fly deploy --local-only

echo "Testing revision endpoint..."
curl -s -X POST https://tsm-shell.fly.dev/api/music/revision/generate \
  -H "Content-Type: application/json" \
  -d '{"draft":"Life surrounded by wrong but trying to stay right is a fight\nEvery day a battle every night a new light","request":"generate 3 options"}'
echo
