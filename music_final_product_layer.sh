#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_final_product_layer

cp -f server.js "backups/music_final_product_layer/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_final_product_layer/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_final_product_layer/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Ensure exactly one stable Fly listener at bottom.
text = re.sub(
    r"\napp\.listen\([^;]*?\);\s*$",
    "",
    text,
    flags=re.S
)

listener = """
app.listen(process.env.PORT || 8080, '0.0.0.0', () => {
  console.log('TSM Shell running on port', process.env.PORT || 8080);
});
"""

# Add final product routes before API 404.
block = r"""
// ===== MUSIC PRODUCT LAYER =====
global.MUSIC_PRODUCT = global.MUSIC_PRODUCT || {
  selectedHistory: [],
  dashboard: {
    lastSelected: null,
    lastHitPotential: null,
    monetizationTier: "Tier 1 · $99/mo",
    status: "ready"
  }
};

function clampMusicWeight(v){
  return Number(Math.max(0.50, Math.min(0.99, v)).toFixed(2));
}

function hitPotential(score){
  const s = score || {};
  const base = ((s.cadence || .7) + (s.emotion || .7) + (s.structure || .7) + (s.imagery || .7)) / 4;
  const percent = Math.round(base * 100);
  let label = "Developing";
  if(percent >= 86) label = "Release Ready";
  else if(percent >= 80) label = "Strong Hook Potential";
  else if(percent >= 74) label = "Needs One More Pass";
  return { percent, label };
}

function reinforceDNA(optionId, score){
  if(!global.MUSIC_ENGINE || !global.MUSIC_ENGINE.dna) return null;
  const dna = global.MUSIC_ENGINE.dna;
  dna.weights = dna.weights || { cadence:.8, emotion:.8, structure:.8, imagery:.8 };

  if(optionId === "A") dna.weights.cadence = clampMusicWeight(dna.weights.cadence + .02);
  if(optionId === "B") {
    dna.weights.emotion = clampMusicWeight(dna.weights.emotion + .02);
    dna.weights.imagery = clampMusicWeight(dna.weights.imagery + .01);
  }
  if(optionId === "C") dna.weights.structure = clampMusicWeight(dna.weights.structure + .02);

  if(score){
    dna.weights.cadence = clampMusicWeight((dna.weights.cadence * .9) + ((score.cadence || dna.weights.cadence) * .1));
    dna.weights.emotion = clampMusicWeight((dna.weights.emotion * .9) + ((score.emotion || dna.weights.emotion) * .1));
    dna.weights.structure = clampMusicWeight((dna.weights.structure * .9) + ((score.structure || dna.weights.structure) * .1));
    dna.weights.imagery = clampMusicWeight((dna.weights.imagery * .9) + ((score.imagery || dna.weights.imagery) * .1));
  }

  dna.updatedAt = new Date().toISOString();
  return dna;
}

app.post('/api/music/revision/pick-rerun', (req, res) => {
  const body = req.body || {};
  const session = global.MUSIC_REVISIONS && global.MUSIC_REVISIONS.sessions
    ? global.MUSIC_REVISIONS.sessions.find(s => String(s.id) === String(body.sessionId))
    : null;

  if(!session) return res.status(404).json({ ok:false, error:"Revision session not found" });

  const option = session.options.find(o => o.id === body.optionId);
  if(!option) return res.status(404).json({ ok:false, error:"Revision option not found" });

  const dna = reinforceDNA(option.id, option.score);
  const nextDraft = option.output;
  const zay = agentPass("ZAY", nextDraft, "Iterative rerun after selected revision");
  const riya = agentPass("RIYA", zay, "Iterative rerun after selected revision");
  const dj = agentPass("DJ", riya, "Iterative rerun after selected revision");
  const score = scoreMusicDraft(dj);
  const hit = hitPotential(score);

  const run = {
    id: Date.now(),
    mode: "pick-rerun",
    selectedOption: option.id,
    input: nextDraft,
    output: dj,
    score,
    hitPotential: hit,
    createdAt: new Date().toISOString()
  };

  if(global.MUSIC_ENGINE){
    global.MUSIC_ENGINE.runs.unshift(run);
    global.MUSIC_ENGINE.runs = global.MUSIC_ENGINE.runs.slice(0,25);
  }

  global.MUSIC_PRODUCT.selectedHistory.unshift({
    sessionId: session.id,
    optionId: option.id,
    score: option.score,
    hitPotential: hit,
    createdAt: new Date().toISOString()
  });
  global.MUSIC_PRODUCT.selectedHistory = global.MUSIC_PRODUCT.selectedHistory.slice(0,25);

  global.MUSIC_PRODUCT.dashboard.lastSelected = option;
  global.MUSIC_PRODUCT.dashboard.lastHitPotential = hit;
  global.MUSIC_PRODUCT.dashboard.status = "iterated";

  return res.json({ ok:true, selected:option, rerun:run, dna, product:global.MUSIC_PRODUCT });
});

app.get('/api/music/dashboard-sync', (_req, res) => {
  return res.json({
    ok:true,
    product:global.MUSIC_PRODUCT,
    engine:global.MUSIC_ENGINE || null,
    revisions:global.MUSIC_REVISIONS || null
  });
});
// ===== END MUSIC PRODUCT LAYER =====
"""

text = re.sub(
    r"\n// ===== MUSIC PRODUCT LAYER =====.*?// ===== END MUSIC PRODUCT LAYER =====\s*",
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
    text = text.rstrip() + "\n" + block
else:
    text = text[:idx] + block + "\n" + text[idx:]

text = text.rstrip() + "\n\n" + listener + "\n"
p.write_text(text, encoding="utf-8")
print("final music product layer inserted + listener normalized")
PY

python3 <<'PY'
from pathlib import Path
import re

client = r"""
<script id="tsm-music-product-ui">
(function(){
  if(window.__TSM_MUSIC_PRODUCT_UI__) return;
  window.__TSM_MUSIC_PRODUCT_UI__ = true;

  window.musicProduct = {
    pickRerun(payload){
      return musicSafeFetch('/api/music/revision/pick-rerun', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload || {})
      });
    },
    dashboard(){
      return musicSafeFetch('/api/music/dashboard-sync');
    }
  };

  window.pickRevisionAndRerun = async function(sessionId, optionId){
    const data = await musicProduct.pickRerun({ sessionId, optionId });
    console.log('Pick + Rerun Complete', data);

    const out =
      document.getElementById('stratOutput') ||
      document.querySelector('[data-agent-output]') ||
      document.getElementById('mainContent');

    if(out && data.ok){
      out.style.display = 'block';
      out.innerHTML = `
        <div style="padding:14px;border:1px solid rgba(16,185,129,.35);background:rgba(6,13,24,.96);border-radius:6px">
          <div style="font-family:var(--mono);font-size:.6rem;color:var(--green);letter-spacing:.12em;text-transform:uppercase;margin-bottom:8px">
            Selected ${data.selected.id} · ${data.rerun.hitPotential.label} · ${data.rerun.hitPotential.percent}%
          </div>
          <pre style="white-space:pre-wrap;max-height:320px;overflow:auto;color:var(--text2);background:var(--bg3);padding:10px;border-radius:4px">${data.rerun.output}</pre>
          <div style="font-family:var(--mono);font-size:.55rem;color:var(--purple);margin-top:8px">
            DNA updated: cadence ${data.dna.weights.cadence} · emotion ${data.dna.weights.emotion} · structure ${data.dna.weights.structure} · imagery ${data.dna.weights.imagery}
          </div>
        </div>`;
    }

    return data;
  };

  window.refreshMusicDashboardSync = async function(){
    const data = await musicProduct.dashboard();
    console.log('Music Dashboard Sync', data);
    return data;
  };
})();
</script>
"""

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")
    html = re.sub(r"<script id=\"tsm-music-product-ui\">.*?</script>", "", html, flags=re.S)

    # Upgrade existing pick buttons to Pick + Run Again when possible.
    html = html.replace("selectRevisionOption('${session.id}','${o.id}')", "pickRevisionAndRerun('${session.id}','${o.id}')")
    html = html.replace("Pick ${o.id}", "Pick + Run Again ${o.id}")

    html = html.replace("</body>", client + "\n</body>") if "</body>" in html else html + "\n" + client
    p.write_text(html, encoding="utf-8")

print("music product UI hooks inserted")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Add Music product layer: DNA weighting, rerun loop, dashboard sync" || true
git push origin main
fly deploy --local-only

echo "Testing product layer..."
SESSION_JSON="$(curl -s -X POST https://tsm-shell.fly.dev/api/music/revision/generate \
  -H "Content-Type: application/json" \
  -d '{"draft":"Life surrounded by wrong but trying to stay right is a fight\nEvery day a battle every night a new light","request":"generate 3 options"}')"

echo "$SESSION_JSON"

SESSION_ID="$(node -e "const j=JSON.parse(process.argv[1]); console.log(j.session.id)" "$SESSION_JSON")"
OPT_ID="$(node -e "const j=JSON.parse(process.argv[1]); console.log(j.session.recommended)" "$SESSION_JSON")"

curl -s -X POST https://tsm-shell.fly.dev/api/music/revision/pick-rerun \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\",\"optionId\":\"$OPT_ID\"}"
echo
