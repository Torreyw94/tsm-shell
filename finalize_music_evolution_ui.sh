#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_evolution_final

cp -f server.js "backups/music_evolution_final/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_evolution_final/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_evolution_final/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Strengthen cleanAgentText to remove all annotation carryover.
clean_fn = r'''function cleanAgentText(text){
  return String(text || "")
    .replace(/\[(ZAY|RIYA|DJ)[^\]]*\]/g, "")
    .replace(/^Agent move:.*$/gm, "")
    .replace(/^DNA influence:.*$/gm, "")
    .replace(/^Cadence note:.*$/gm, "")
    .replace(/^Tone note:.*$/gm, "")
    .replace(/^Arrangement note:.*$/gm, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}
'''

if "function cleanAgentText(text)" in text:
    start = text.find("function cleanAgentText(text)")
    end = text.find("\nfunction agentPass", start)
    if end == -1:
        raise SystemExit("agentPass not found after cleanAgentText")
    text = text[:start] + clean_fn + "\n" + text[end+1:]
else:
    idx = text.find("function agentPass(agent, draft, request)")
    if idx == -1:
        raise SystemExit("agentPass not found")
    text = text[:idx] + clean_fn + "\n" + text[idx:]

# Ensure chain route uses clean pass-to-pass content.
text = re.sub(
    r'const zay = agentPass\("ZAY", draft, request\);\s*const riya = agentPass\("RIYA", zay, request\);\s*const dj = agentPass\("DJ", riya, request\);',
    'const baseDraft = cleanAgentText(draft);\n  const zay = agentPass("ZAY", baseDraft, request);\n  const riya = agentPass("RIYA", cleanAgentText(zay), request);\n  const dj = agentPass("DJ", cleanAgentText(riya), request);',
    text
)

# Ensure pick-rerun uses clean pass-to-pass content.
text = re.sub(
    r'const cleanSelected = cleanAgentText\(option\.output\);\s*const rerunZay = agentPass\("ZAY", cleanSelected, "Pick \+ rerun"\);\s*const rerunRiya = agentPass\("RIYA", rerunZay, "Pick \+ rerun"\);\s*const rerunOutput = agentPass\("DJ", rerunRiya, "Pick \+ rerun"\);',
    'const cleanSelected = cleanAgentText(option.output);\n  const rerunZay = agentPass("ZAY", cleanSelected, "Pick + rerun");\n  const rerunRiya = agentPass("RIYA", cleanAgentText(rerunZay), "Pick + rerun");\n  const rerunOutput = agentPass("DJ", cleanAgentText(rerunRiya), "Pick + rerun");',
    text
)

# Add/replace evolution endpoint.
evo = r'''
// ===== MUSIC EVOLUTION TIMELINE =====
app.get('/api/music/evolution', (_req, res) => {
  const runs = global.MUSIC_ENGINE && global.MUSIC_ENGINE.runs ? global.MUSIC_ENGINE.runs : [];
  const product = global.MUSIC_PRODUCT || {};
  const dna = global.MUSIC_ENGINE && global.MUSIC_ENGINE.dna ? global.MUSIC_ENGINE.dna : null;

  const timeline = runs.slice(0, 12).map((r, i) => ({
    index: i,
    label: r.mode || "run",
    overall: r.score && r.score.overall ? r.score.overall : 0,
    score: r.score || {},
    hitPotential: r.hitPotential || null,
    createdAt: r.createdAt
  })).reverse();

  const latest = timeline[timeline.length - 1] || null;
  const previous = timeline[timeline.length - 2] || null;
  const delta = latest && previous ? Number((latest.overall - previous.overall).toFixed(2)) : 0;

  let hit = latest && latest.hitPotential ? latest.hitPotential : null;
  if(!hit && typeof hitPotential === "function"){
    hit = hitPotential(latest ? latest.score : {});
  }

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
    dna,
    product
  });
});
// ===== END MUSIC EVOLUTION TIMELINE =====

'''

text = re.sub(
    r'\n// ===== MUSIC EVOLUTION TIMELINE =====.*?// ===== END MUSIC EVOLUTION TIMELINE =====\s*',
    '\n',
    text,
    flags=re.S
)

idx = text.find("app.use((req, res) => {")
if idx == -1:
    idx = text.find("res.status(404).json({ ok: false, error: 'API route not found' });")
if idx == -1:
    raise SystemExit("API 404 block not found")

text = text[:idx] + evo + text[idx:]

p.write_text(text, encoding="utf-8")
print("server: clean chaining + evolution endpoint finalized")
PY

python3 <<'PY'
from pathlib import Path
import re

client = r'''
<script id="tsm-music-evolution-final-ui">
(function(){
  if(window.__TSM_MUSIC_EVOLUTION_FINAL_UI__) return;
  window.__TSM_MUSIC_EVOLUTION_FINAL_UI__ = true;

  window.musicEvolution = {
    state(){
      return musicSafeFetch('/api/music/evolution');
    }
  };

  function pct(v){ return Math.round(Number(v || 0) * 100); }

  function miniBar(label, value){
    const p = pct(value);
    return `
      <div style="margin:8px 0">
        <div style="display:flex;justify-content:space-between;font-family:var(--mono);font-size:.55rem;color:var(--text2)">
          <span>${label}</span><span>${p}%</span>
        </div>
        <div style="height:6px;background:rgba(255,255,255,.08);border-radius:999px;overflow:hidden">
          <div style="width:${p}%;height:100%;background:linear-gradient(90deg,#14f195,#a855f7);"></div>
        </div>
      </div>`;
  }

  function decisionColor(decision){
    if(decision === 'Release') return '#14f195';
    if(decision && decision.includes('Scrap')) return '#fb7185';
    return '#fbbf24';
  }

  window.renderMusicEvolutionPanel = function(data){
    if(!data || !data.ok) return;

    let panel = document.getElementById('music-evolution-panel');
    if(!panel){
      panel = document.createElement('section');
      panel.id = 'music-evolution-panel';
      panel.style.cssText = `
        margin-top:14px;
        padding:14px;
        border:1px solid rgba(20,241,149,.28);
        background:rgba(5,10,20,.96);
        border-radius:10px;
        box-shadow:0 0 28px rgba(20,241,149,.08);
      `;

      const target =
        document.getElementById('mainContent') ||
        document.querySelector('main') ||
        document.querySelector('.main') ||
        document.body;

      target.appendChild(panel);
    }

    const timeline = data.timeline || [];
    const latest = data.latest || {};
    const score = latest.score || {};
    const hit = data.hit || { percent:0, label:'No trajectory yet' };
    const dna = data.dna || { weights:{}, learnedSongs:[] };
    const weights = dna.weights || {};
    const decision = data.decision || 'Iterate Again';
    const color = decisionColor(decision);

    panel.innerHTML = `
      <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start">
        <div>
          <div style="font-family:var(--mono);font-size:.58rem;color:#14f195;letter-spacing:.14em;text-transform:uppercase">
            Music Decision Engine · Evolution Timeline
          </div>
          <h3 style="margin:6px 0 4px;font-family:var(--head);color:${color}">
            ${decision} · ${hit.percent || 0}%
          </h3>
          <div style="font-size:.75rem;color:var(--text2)">
            ${hit.label || 'No hit label'} · Score Delta ${data.delta >= 0 ? '+' : ''}${data.delta || 0}
          </div>
        </div>
        <button class="btn btn-purple" onclick="refreshMusicEvolutionPanel()">Refresh Evolution</button>
      </div>

      <div style="display:grid;grid-template-columns:1.15fr .85fr;gap:14px;margin-top:12px">
        <div>
          <div style="font-family:var(--mono);font-size:.55rem;color:#a855f7;letter-spacing:.12em;text-transform:uppercase;margin-bottom:8px">
            Hit Trajectory
          </div>
          <div style="display:flex;gap:6px;align-items:flex-end;height:105px;border:1px solid rgba(255,255,255,.08);padding:8px;border-radius:8px;background:rgba(255,255,255,.03)">
            ${
              timeline.length ? timeline.map(t => `
                <div title="${t.label} · ${pct(t.overall)}%" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:4px">
                  <div style="width:100%;height:${Math.max(8, Math.round((t.overall||0)*90))}px;background:linear-gradient(180deg,#a855f7,#14f195);border-radius:5px 5px 0 0"></div>
                  <span style="font-family:var(--mono);font-size:.48rem;color:var(--text2)">${pct(t.overall)}</span>
                </div>
              `).join('') : `<div style="color:var(--text2);font-size:.75rem">No runs yet. Generate revision mode first.</div>`
            }
          </div>

          <div style="margin-top:10px;border:1px solid rgba(255,255,255,.08);border-radius:8px;padding:10px;background:rgba(255,255,255,.025)">
            <div style="font-family:var(--mono);font-size:.55rem;color:#a855f7;text-transform:uppercase;letter-spacing:.12em;margin-bottom:7px">
              Release Decision
            </div>
            <div style="font-size:.78rem;color:var(--text2);line-height:1.45">
              ${
                decision === 'Release'
                ? 'This version has crossed the release-ready threshold. Next move: finalize arrangement, create campaign assets, and push to release pipeline.'
                : decision.includes('Scrap')
                ? 'The hook needs rework before release consideration. Next move: revise concept or rebuild the chorus.'
                : 'This is promising but needs another iteration. Next move: pick the strongest option and rerun.'
              }
            </div>
          </div>
        </div>

        <div>
          <div style="font-family:var(--mono);font-size:.55rem;color:#a855f7;letter-spacing:.12em;text-transform:uppercase;margin-bottom:8px">
            Latest Score
          </div>
          ${miniBar('Cadence', score.cadence)}
          ${miniBar('Emotion', score.emotion)}
          ${miniBar('Structure', score.structure)}
          ${miniBar('Imagery', score.imagery)}

          <div style="margin-top:12px;font-family:var(--mono);font-size:.55rem;color:#a855f7;letter-spacing:.12em;text-transform:uppercase">
            DNA Evolution
          </div>
          <div style="margin-top:7px;font-family:var(--mono);font-size:.57rem;color:var(--text2);line-height:1.6">
            Cad ${weights.cadence ?? '-'} · Emo ${weights.emotion ?? '-'}<br>
            Str ${weights.structure ?? '-'} · Img ${weights.imagery ?? '-'}<br>
            Learned Songs: ${(dna.learnedSongs || []).length}
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

  const priorPick = window.pickRevisionAndRerun;
  if(typeof priorPick === 'function' && !priorPick.__evolutionWrapped){
    const wrapped = async function(sessionId, optionId){
      const result = await priorPick(sessionId, optionId);
      setTimeout(refreshMusicEvolutionPanel, 300);
      return result;
    };
    wrapped.__evolutionWrapped = true;
    window.pickRevisionAndRerun = wrapped;
  }

  window.addEventListener('load', function(){
    setTimeout(refreshMusicEvolutionPanel, 900);
  });
})();
</script>
'''

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")
    html = re.sub(r'<script id="tsm-music-evolution-final-ui">.*?</script>', '', html, flags=re.S)
    html = re.sub(r'<script id="tsm-music-evolution-ui">.*?</script>', '', html, flags=re.S)
    html = html.replace("</body>", client + "\n</body>") if "</body>" in html else html + "\n" + client
    p.write_text(html, encoding="utf-8")

print("frontend: evolution panel finalized")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Finalize Music evolution timeline and clean chaining UI" || true
git push origin main
fly deploy --local-only

echo "Testing clean chain..."
curl -s -X POST https://tsm-shell.fly.dev/api/music/agent/chain \
  -H "Content-Type: application/json" \
  -d '{"draft":"Life surrounded by wrong but trying to stay right is a fight\nEvery day a battle every night a new light","request":"full chain"}'
echo

echo "Testing evolution..."
curl -s https://tsm-shell.fly.dev/api/music/evolution
echo
