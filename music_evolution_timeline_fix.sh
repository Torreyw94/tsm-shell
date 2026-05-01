#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_evolution_timeline

cp -f server.js "backups/music_evolution_timeline/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_evolution_timeline/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_evolution_timeline/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1) Replace agentPass with clean, non-stacking version.
new_agent = r"""
function cleanAgentText(text){
  return String(text || "")
    .replace(/\[(ZAY|RIYA|DJ)[^\]]*\]/g, "")
    .replace(/^Agent move:.*$/gm, "")
    .replace(/^Cadence note:.*$/gm, "")
    .replace(/^Tone note:.*$/gm, "")
    .replace(/^Arrangement note:.*$/gm, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function agentPass(agent, draft, request){
  const a = String(agent || "ZAY").toUpperCase();
  const base = cleanAgentText(draft || "");
  const dna = global.MUSIC_ENGINE && global.MUSIC_ENGINE.dna ? global.MUSIC_ENGINE.dna : {};
  const weights = dna.weights || { cadence:.8, emotion:.8, structure:.8, imagery:.8 };
  const terms = (dna.styleTerms || []).join(", ");

  if (a === "ZAY") {
    return "[ZAY — CADENCE / BOUNCE]\n\n" + base +
      "\n\nAgent move: tighten rhythm, shorten heavy phrasing, and make the last phrase hit in-pocket." +
      "\nDNA influence: cadence " + weights.cadence + " · style terms " + terms;
  }

  if (a === "RIYA") {
    return "[RIYA — EMOTION / IMAGERY]\n\n" + base +
      "\n\nAgent move: make the emotional image more specific while keeping the artist voice plain-spoken." +
      "\nDNA influence: emotion " + weights.emotion + " · imagery " + weights.imagery;
  }

  if (a === "DJ") {
    return "[DJ — STRUCTURE / HOOK]\n\n" + base +
      "\n\nAgent move: move the strongest repeatable phrase into hook position and clean the transition." +
      "\nDNA influence: structure " + weights.structure;
  }

  return base;
}
"""

text = re.sub(
    r"function agentPass\(agent, draft, request\)\{.*?\n\}",
    new_agent,
    text,
    count=1,
    flags=re.S
)

# 2) Fix pick-rerun to chain cleanly.
text = re.sub(
    r"const rerunOutput = agentPass\(\"DJ\", agentPass\(\"RIYA\", agentPass\(\"ZAY\", option\.output, \"Pick \+ rerun\"\), \"Pick \+ rerun\"\), \"Pick \+ rerun\"\);",
    """const cleanSelected = cleanAgentText(option.output);
  const rerunZay = agentPass("ZAY", cleanSelected, "Pick + rerun");
  const rerunRiya = agentPass("RIYA", rerunZay, "Pick + rerun");
  const rerunOutput = agentPass("DJ", rerunRiya, "Pick + rerun");""",
    text
)

# 3) Add evolution endpoint before API 404.
text = re.sub(
    r"\n// ===== MUSIC EVOLUTION TIMELINE =====.*?// ===== END MUSIC EVOLUTION TIMELINE =====\s*",
    "\n",
    text,
    flags=re.S
)

evolution = r"""
// ===== MUSIC EVOLUTION TIMELINE =====
app.get('/api/music/evolution', (_req, res) => {
  const runs = global.MUSIC_ENGINE && global.MUSIC_ENGINE.runs ? global.MUSIC_ENGINE.runs : [];
  const selected = global.MUSIC_PRODUCT && global.MUSIC_PRODUCT.selectedHistory ? global.MUSIC_PRODUCT.selectedHistory : [];

  const timeline = runs.slice(0, 12).map((r, i) => ({
    label: r.mode || "run",
    score: r.score || {},
    overall: r.score && r.score.overall ? r.score.overall : 0,
    hitPotential: r.hitPotential || null,
    createdAt: r.createdAt,
    index: i
  })).reverse();

  const latest = timeline[timeline.length - 1] || null;
  const previous = timeline[timeline.length - 2] || null;
  const delta = latest && previous ? Number((latest.overall - previous.overall).toFixed(2)) : 0;
  const hit = latest && latest.hitPotential ? latest.hitPotential : (typeof hitPotential === "function" ? hitPotential(latest ? latest.score : {}) : null);

  let decision = "Iterate Again";
  if(hit && hit.percent >= 86) decision = "Release";
  else if(hit && hit.percent < 74) decision = "Scrap / Rework Hook";

  return res.json({
    ok:true,
    timeline,
    latest,
    previous,
    delta,
    hit,
    decision,
    selected,
    dna: global.MUSIC_ENGINE ? global.MUSIC_ENGINE.dna : null
  });
});
// ===== END MUSIC EVOLUTION TIMELINE =====

"""

idx = text.find("app.use((req, res) => {")
if idx == -1:
    idx = text.find("res.status(404).json({ ok: false, error: 'API route not found' });")
if idx == -1:
    raise SystemExit("Could not find API 404 block")

text = text[:idx] + evolution + text[idx:]
p.write_text(text, encoding="utf-8")
print("server cleaned agent stacking + added evolution endpoint")
PY

python3 <<'PY'
from pathlib import Path
import re

client = r"""
<script id="tsm-music-evolution-ui">
(function(){
  if(window.__TSM_MUSIC_EVOLUTION_UI__) return;
  window.__TSM_MUSIC_EVOLUTION_UI__ = true;

  window.musicEvolution = {
    state(){ return musicSafeFetch('/api/music/evolution'); }
  };

  function bar(label, value){
    const pct = Math.round((Number(value || 0)) * 100);
    return `
      <div style="margin:7px 0">
        <div style="display:flex;justify-content:space-between;font-family:var(--mono);font-size:.55rem;color:var(--text2)">
          <span>${label}</span><span>${pct}%</span>
        </div>
        <div style="height:6px;background:rgba(255,255,255,.08);border-radius:999px;overflow:hidden">
          <div style="width:${pct}%;height:100%;background:linear-gradient(90deg,#14f195,#a855f7);"></div>
        </div>
      </div>`;
  }

  window.renderMusicEvolutionPanel = function(data){
    let panel = document.getElementById('music-evolution-panel');
    if(!panel){
      panel = document.createElement('section');
      panel.id = 'music-evolution-panel';
      panel.style.cssText = `
        margin-top:14px;
        padding:14px;
        border:1px solid rgba(20,241,149,.28);
        background:rgba(5,10,20,.94);
        border-radius:8px;
        box-shadow:0 0 24px rgba(20,241,149,.08);
      `;

      const target =
        document.getElementById('mainContent') ||
        document.querySelector('main') ||
        document.body;

      target.appendChild(panel);
    }

    const timeline = (data && data.timeline) || [];
    const latest = data.latest || {};
    const score = latest.score || {};
    const hit = data.hit || { percent:0, label:'No trajectory yet' };
    const dna = data.dna || { weights:{} };

    panel.innerHTML = `
      <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start">
        <div>
          <div style="font-family:var(--mono);font-size:.58rem;color:var(--green);letter-spacing:.14em;text-transform:uppercase">
            Hit Trajectory · Music Decision Engine
          </div>
          <h3 style="margin:6px 0 4px;font-family:var(--head);color:var(--text)">
            ${data.decision || 'Iterate Again'} · ${hit.percent || 0}%
          </h3>
          <div style="font-size:.75rem;color:var(--text2)">
            ${hit.label || 'No hit label'} · Delta ${data.delta >= 0 ? '+' : ''}${data.delta || 0}
          </div>
        </div>
        <button class="btn btn-purple" onclick="refreshMusicEvolutionPanel()">Refresh Evolution</button>
      </div>

      <div style="display:grid;grid-template-columns:1.1fr .9fr;gap:14px;margin-top:12px">
        <div>
          <div style="font-family:var(--mono);font-size:.55rem;color:var(--purple);letter-spacing:.12em;text-transform:uppercase;margin-bottom:8px">
            Evolution Timeline
          </div>
          <div style="display:flex;gap:6px;align-items:flex-end;height:90px;border:1px solid rgba(255,255,255,.08);padding:8px;border-radius:6px;background:rgba(255,255,255,.03)">
            ${
              timeline.length ? timeline.map(t => `
                <div title="${t.label} · ${Math.round((t.overall||0)*100)}%" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:4px">
                  <div style="width:100%;height:${Math.max(8, Math.round((t.overall||0)*80))}px;background:linear-gradient(180deg,#a855f7,#14f195);border-radius:4px 4px 0 0"></div>
                  <span style="font-family:var(--mono);font-size:.48rem;color:var(--text2)">${Math.round((t.overall||0)*100)}</span>
                </div>
              `).join('') : `<div style="color:var(--text2);font-size:.75rem">No runs yet. Generate revision mode first.</div>`
            }
          </div>
        </div>

        <div>
          <div style="font-family:var(--mono);font-size:.55rem;color:var(--purple);letter-spacing:.12em;text-transform:uppercase;margin-bottom:8px">
            Latest Score + DNA Weights
          </div>
          ${bar('Cadence', score.cadence)}
          ${bar('Emotion', score.emotion)}
          ${bar('Structure', score.structure)}
          ${bar('Imagery', score.imagery)}
          <div style="margin-top:8px;font-family:var(--mono);font-size:.55rem;color:var(--text2)">
            DNA: cad ${dna.weights?.cadence ?? '-'} · emo ${dna.weights?.emotion ?? '-'} · str ${dna.weights?.structure ?? '-'} · img ${dna.weights?.imagery ?? '-'}
          </div>
        </div>
      </div>
    `;
  };

  window.refreshMusicEvolutionPanel = async function(){
    const data = await musicEvolution.state();
    if(data && data.ok) renderMusicEvolutionPanel(data);
    console.log('Music Evolution', data);
    return data;
  };

  const oldPick = window.pickRevisionAndRerun;
  if(typeof oldPick === 'function'){
    window.pickRevisionAndRerun = async function(sessionId, optionId){
      const result = await oldPick(sessionId, optionId);
      setTimeout(refreshMusicEvolutionPanel, 300);
      return result;
    };
  }

  window.addEventListener('load', function(){
    setTimeout(refreshMusicEvolutionPanel, 900);
  });
})();
</script>
"""

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")
    html = re.sub(r"<script id=\"tsm-music-evolution-ui\">.*?</script>", "", html, flags=re.S)
    html = html.replace("</body>", client + "\n</body>") if "</body>" in html else html + "\n" + client
    p.write_text(html, encoding="utf-8")

print("evolution UI injected")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Add Music evolution timeline and clean agent chaining" || true
git push origin main
fly deploy --local-only

echo "Testing evolution endpoint..."
curl -s https://tsm-shell.fly.dev/api/music/evolution
echo
