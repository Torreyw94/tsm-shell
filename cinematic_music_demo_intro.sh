#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/music-command/presentation-live.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_cinematic_intro
cp -f "$FILE" "backups/music_cinematic_intro/presentation-live.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/presentation-live.html")
html = p.read_text(encoding="utf-8", errors="ignore")

css = r'''
<style id="tsm-cinematic-demo-css">
#cinematic-demo-panel{
  margin-top:24px;
  max-width:980px;
  border:1px solid rgba(20,241,149,.28);
  background:rgba(5,10,20,.90);
  border-radius:18px;
  padding:18px;
  box-shadow:0 0 34px rgba(20,241,149,.10);
}
.cine-top{
  display:flex;
  justify-content:space-between;
  gap:14px;
  align-items:flex-start;
  margin-bottom:14px;
}
.cine-kicker{
  font-family:var(--mono);
  font-size:11px;
  color:var(--teal);
  letter-spacing:.16em;
  text-transform:uppercase;
}
.cine-status{
  font-family:var(--mono);
  font-size:10px;
  color:var(--gold);
  letter-spacing:.12em;
  text-transform:uppercase;
}
.cine-agents{
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:10px;
  margin:14px 0;
}
.cine-agent{
  border:1px solid rgba(255,255,255,.08);
  background:rgba(255,255,255,.035);
  border-radius:14px;
  padding:13px;
  transition:.25s ease;
}
.cine-agent.active{
  border-color:rgba(20,241,149,.65);
  box-shadow:0 0 24px rgba(20,241,149,.14);
  transform:translateY(-2px);
}
.cine-agent b{
  display:block;
  font-family:var(--head);
  color:var(--text);
  font-size:20px;
}
.cine-agent span{
  font-family:var(--mono);
  font-size:10px;
  color:var(--muted);
  letter-spacing:.12em;
  text-transform:uppercase;
}
.cine-output{
  white-space:pre-wrap;
  max-height:210px;
  overflow:auto;
  border:1px solid rgba(255,255,255,.08);
  background:rgba(0,0,0,.30);
  border-radius:12px;
  padding:13px;
  font-family:var(--mono);
  font-size:12px;
  line-height:1.55;
  color:#d1d5db;
}
.cine-score-wrap{
  margin-top:12px;
}
.cine-score-label{
  display:flex;
  justify-content:space-between;
  font-family:var(--mono);
  font-size:10px;
  color:var(--muted);
  letter-spacing:.1em;
  text-transform:uppercase;
}
.cine-score-track{
  height:8px;
  margin-top:6px;
  background:rgba(255,255,255,.08);
  border-radius:999px;
  overflow:hidden;
}
#cine-score-bar{
  width:0%;
  height:100%;
  background:linear-gradient(90deg,var(--teal),var(--purple),var(--gold));
  transition:width .7s ease;
}
.cine-recommend{
  margin-top:12px;
  border:1px solid rgba(255,210,48,.28);
  background:rgba(255,210,48,.07);
  border-radius:12px;
  padding:12px;
  color:#fde68a;
  font-size:13px;
  line-height:1.45;
}
.cine-actions{
  display:flex;
  gap:10px;
  flex-wrap:wrap;
  margin-top:12px;
}
@media(max-width:900px){
  .cine-agents{grid-template-columns:1fr}
}
</style>
'''

if "tsm-cinematic-demo-css" not in html:
    html = html.replace("</head>", css + "\n</head>")

panel = r'''
<div id="cinematic-demo-panel">
  <div class="cine-top">
    <div>
      <div class="cine-kicker">Cinematic Live Demo</div>
      <div style="color:var(--muted);font-size:13px;margin-top:4px;">Watch the system wake up: DNA → agents → score → recommendation.</div>
    </div>
    <div class="cine-status" id="cine-status">READY</div>
  </div>

  <div class="cine-agents">
    <div class="cine-agent" id="cine-zay"><b>ZAY</b><span>Cadence · Bounce · Flow</span></div>
    <div class="cine-agent" id="cine-riya"><b>RIYA</b><span>Emotion · Imagery · Voice</span></div>
    <div class="cine-agent" id="cine-dj"><b>DJ</b><span>Structure · Hook · Transitions</span></div>
  </div>

  <div class="cine-output" id="cine-output">Protected demo ready. Start the live demo or wait for auto-run.</div>

  <div class="cine-score-wrap">
    <div class="cine-score-label"><span>Hit Potential Score</span><span id="cine-score">—</span></div>
    <div class="cine-score-track"><div id="cine-score-bar"></div></div>
  </div>

  <div class="cine-recommend" id="cine-recommend">
    Recommendation will appear after the agent chain runs.
  </div>

  <div class="cine-actions">
    <button class="btn primary" onclick="runCinematicDemo(true)">Run Cinematic Demo</button>
    <button class="btn purple" onclick="showProspectLyricPrompt()">Run Your Own Lyrics</button>
  </div>
</div>
'''

# Insert panel after CTA block if not present
if 'id="cinematic-demo-panel"' not in html:
    # Best anchor: closer proof, guided demo, or footer
    if 'id="closerProof"' in html:
        html = html.replace('<div class="liveProof" id="closerProof">', panel + '\n\n  <div class="liveProof" id="closerProof">')
    elif 'id="guided-demo"' in html:
        html = html.replace('<div id="guided-demo"', panel + '\n\n  <div id="guided-demo"')
    else:
        html = html.replace('<div class="footer">Use ↑ / ↓ arrows to navigate</div>', panel + '\n  <div class="footer">Use ↑ / ↓ arrows to navigate</div>')

js = r'''
<script id="tsm-cinematic-demo-js">
(function(){
  if(window.__TSM_CINEMATIC_DEMO__) return;
  window.__TSM_CINEMATIC_DEMO__ = true;

  function token(){
    return new URLSearchParams(location.search).get('demo_token') || localStorage.getItem('tsm_music_demo_token') || '';
  }

  function sleep(ms){ return new Promise(r => setTimeout(r, ms)); }

  function setText(id, val){
    const el = document.getElementById(id);
    if(el) el.textContent = val;
  }

  function setOutput(val){
    const el = document.getElementById('cine-output');
    if(el) el.textContent = val;
  }

  function activate(id){
    ['cine-zay','cine-riya','cine-dj'].forEach(x => {
      const el = document.getElementById(x);
      if(el) el.classList.remove('active');
    });
    const el = document.getElementById(id);
    if(el) el.classList.add('active');
  }

  function scoreToPercent(score){
    return Math.round(Number(score || 0) * 100);
  }

  async function callChain(draft){
    const t = token();
    const url = '/api/music/agent/chain' + (t ? '?demo_token=' + encodeURIComponent(t) : '');
    const res = await fetch(url, {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({ draft, request:'cinematic closer demo' })
    });
    return await res.json();
  }

  window.runCinematicDemo = async function(force){
    if(!force && sessionStorage.getItem('tsm_cinematic_demo_ran')) return;
    sessionStorage.setItem('tsm_cinematic_demo_ran','1');

    const sample = `Life surrounded by wrong but trying to stay right is a fight
Every day a battle every night a new light`;

    setText('cine-status','BOOTING');
    setOutput(`Initializing ZY Music Command...
Loading Artist DNA...
Preparing private demo environment...
Activating agents...`);
    await sleep(700);

    activate('cine-zay');
    setText('cine-status','ZAY ACTIVE');
    setOutput(`ZAY is reading cadence...
Checking bounce, pocket, and phrasing...

Input:
${sample}`);
    await sleep(850);

    activate('cine-riya');
    setText('cine-status','RIYA ACTIVE');
    setOutput(`RIYA is reading emotional center...
Checking imagery, vulnerability, and voice...

ZAY pass complete.`);
    await sleep(850);

    activate('cine-dj');
    setText('cine-status','DJ ACTIVE');
    setOutput(`DJ is reading structure...
Checking hook position, transitions, and repeatability...

Running full agent chain...`);
    await sleep(850);

    const data = await callChain(sample);

    if(!data.ok){
      setText('cine-status','LOCKED');
      setOutput('Demo could not run: ' + (data.error || 'access blocked'));
      setText('cine-recommend','Request a fresh private demo link to unlock the live agent chain.');
      return data;
    }

    const run = data.run || {};
    const score = scoreToPercent(run.score && run.score.overall);
    document.getElementById('cine-score-bar').style.width = Math.max(0, score) + '%';
    setText('cine-score', score ? score + '%' : '—');

    setText('cine-status','LIVE RESULT');
    setOutput((run.output || JSON.stringify(data,null,2)).slice(0,1200));

    let label = 'Iterate Again';
    if(score >= 86) label = 'Release Ready';
    else if(score < 74) label = 'Rework Hook';

    setText('cine-recommend',
      `Recommended next move: ${label}. ZAY tightened cadence, RIYA sharpened emotion, and DJ structured the hook path. This is decision intelligence — not random generation.`);

    if(typeof refreshCloserProof === 'function') {
      setTimeout(refreshCloserProof, 400);
    }

    setTimeout(() => {
      if(!sessionStorage.getItem('tsm_cinematic_prompt_seen')){
        sessionStorage.setItem('tsm_cinematic_prompt_seen','1');
        showProspectLyricPrompt();
      }
    }, 1400);

    return data;
  };

  window.showProspectLyricPrompt = function(){
    let modal = document.getElementById('prospect-lyric-modal');
    if(!modal){
      modal = document.createElement('div');
      modal.id = 'prospect-lyric-modal';
      modal.style.cssText = `
        position:fixed;
        inset:0;
        background:rgba(0,0,0,.72);
        z-index:999999;
        display:flex;
        align-items:center;
        justify-content:center;
        padding:22px;
      `;
      document.body.appendChild(modal);
    }

    modal.innerHTML = `
      <div style="width:min(760px,100%);background:#050b14;border:1px solid rgba(168,85,247,.5);border-radius:18px;padding:18px;box-shadow:0 0 44px rgba(168,85,247,.18);color:#fff;">
        <div style="font-family:monospace;font-size:11px;color:#a855f7;letter-spacing:.14em;text-transform:uppercase">Run Your Own Lyrics</div>
        <h2 style="margin:8px 0 10px;font-family:Arial Black,Impact,sans-serif">Want to see it work on your song?</h2>
        <p style="color:#9ca3af;line-height:1.55;margin:0 0 12px">Paste a hook, verse, or rough idea. The demo will run the same ZAY → RIYA → DJ decision chain.</p>
        <textarea id="prospectLyrics" style="width:100%;height:130px;background:#07090f;color:#fff;border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px;">Life surrounded by wrong but trying to stay right is a fight
Every day a battle every night a new light</textarea>
        <div style="display:flex;gap:10px;margin-top:12px;flex-wrap:wrap">
          <button class="btn primary" onclick="runProspectLyrics()">Run My Lyrics</button>
          <button class="btn" onclick="document.getElementById('prospect-lyric-modal').remove()">Close</button>
        </div>
      </div>`;
  };

  window.runProspectLyrics = async function(){
    const input = document.getElementById('prospectLyrics');
    const text = input ? input.value : '';
    document.getElementById('prospect-lyric-modal')?.remove();

    setText('cine-status','RUNNING PROSPECT LYRICS');
    setOutput('Running your lyrics through ZAY → RIYA → DJ...');
    activate('cine-zay');

    const data = await callChain(text);
    const run = data.run || {};
    const score = scoreToPercent(run.score && run.score.overall);

    activate('cine-dj');
    document.getElementById('cine-score-bar').style.width = Math.max(0, score) + '%';
    setText('cine-score', score ? score + '%' : '—');
    setText('cine-status','CUSTOM RESULT');
    setOutput((run.output || JSON.stringify(data,null,2)).slice(0,1200));
    setText('cine-recommend', `This is where the prospect feels ownership: their lyrics, scored and improved live. Score: ${score || '—'}%.`);

    return data;
  };

  window.addEventListener('load', function(){
    const hasToken = !!token();
    if(hasToken){
      setTimeout(() => runCinematicDemo(false), 1200);
    }
  });
})();
</script>
'''

html = re.sub(r'<script id="tsm-cinematic-demo-js">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", js + "\n</body>")

p.write_text(html, encoding="utf-8")
print("cinematic demo intro applied")
PY

node -c server.js

git add "$FILE"
git commit -m "Add cinematic AI intro to Music live presentation" || true
fly deploy --local-only

echo "Open with token:"
echo "https://tsm-shell.fly.dev/html/music-command/presentation-live.html?demo_token=YOUR_TOKEN&v=cinematic"
