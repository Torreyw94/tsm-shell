#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/guided_creation_loop
cp -f "$FILE" "backups/guided_creation_loop/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

css = r'''
<style id="guided-creation-loop-css">
.loop-actions{
  display:flex;
  gap:10px;
  flex-wrap:wrap;
  margin:12px 0 18px;
}
.btn-loop{
  background:rgba(57,217,138,.12);
  color:#39d98a;
  border:1px solid rgba(57,217,138,.35);
  padding:9px 14px;
  border-radius:7px;
  cursor:pointer;
  font-weight:700;
}
.btn-loop:hover{
  background:rgba(57,217,138,.2);
}
.btn-loop.secondary{
  background:transparent;
  color:#ffb347;
  border-color:rgba(255,179,71,.35);
}
.loop-toast{
  position:fixed;
  left:50%;
  bottom:28px;
  transform:translateX(-50%);
  z-index:99999;
  background:#0f1726;
  border:1px solid rgba(57,217,138,.35);
  color:#e8e8f0;
  padding:12px 16px;
  border-radius:999px;
  font-family:var(--mono,monospace);
  font-size:11px;
  box-shadow:0 0 30px rgba(57,217,138,.12);
}
.evolution-dots{
  display:flex;
  gap:6px;
  align-items:flex-end;
  height:46px;
  margin-top:10px;
}
.evolution-dot{
  flex:1;
  min-height:6px;
  background:linear-gradient(180deg,#39d98a,#5b9cf6);
  border-radius:5px 5px 0 0;
}
</style>
'''

if "guided-creation-loop-css" not in html:
    html = html.replace("</head>", css + "\n</head>")

# Add loop action container after versions grid if not already present
if 'id="guidedLoopActions"' not in html:
    html = html.replace(
        '<div class="section-label">Agent Analysis</div>',
        '''<div id="guidedLoopActions" class="loop-actions" style="display:none">
            <button class="btn-loop" onclick="improveRecommended()">↻ Improve Picked Version</button>
            <button class="btn-loop secondary" onclick="copyRecommended()">Copy Recommended</button>
          </div>

          <div class="section-label">Agent Analysis</div>'''
    )

js = r'''
<script id="guided-creation-loop-js">
(function(){
  if(window.__GUIDED_CREATION_LOOP__) return;
  window.__GUIDED_CREATION_LOOP__ = true;

  window.__musicEvolutionScores = window.__musicEvolutionScores || [];

  function toast(msg){
    let el = document.createElement('div');
    el.className = 'loop-toast';
    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(()=>el.remove(), 2200);
  }

  function recommendedText(){
    const el = document.querySelector('.version-card.recommended .version-text');
    return el ? el.innerText.trim() : '';
  }

  window.copyRecommended = async function(){
    const txt = recommendedText();
    if(!txt) return toast('No recommended version yet');
    try{
      await navigator.clipboard.writeText(txt);
      toast('Recommended version copied');
    }catch(e){
      toast('Copy failed — select manually');
    }
  };

  window.improveRecommended = function(){
    const txt = recommendedText();
    if(!txt) return toast('Run analysis first');
    const input = document.getElementById('lyricInput');
    if(input){
      input.value = txt;
      toast('Recommended version loaded — improving again');
      setTimeout(()=>runAnalysis(), 450);
    }
  };

  function enhanceAfterRender(){
    const actions = document.getElementById('guidedLoopActions');
    if(actions) actions.style.display = 'flex';

    const scoreEl = document.getElementById('hitScore');
    const score = scoreEl ? parseInt(scoreEl.textContent,10) : 0;
    if(score){
      window.__musicEvolutionScores.push(score);
      window.__musicEvolutionScores = window.__musicEvolutionScores.slice(-8);
      renderEvolutionMini();
    }

    if(!sessionStorage.getItem('zy_loop_prompt_seen')){
      sessionStorage.setItem('zy_loop_prompt_seen','1');
      setTimeout(()=>{
        toast('Tip: click “Improve Picked Version” to keep building the song');
      }, 900);
    }
  }

  function renderEvolutionMini(){
    const box = document.getElementById('trajectoryBox');
    if(!box) return;
    const scores = window.__musicEvolutionScores;
    const bars = scores.map(s=>`<div class="evolution-dot" title="${s}%" style="height:${Math.max(8,s/2)}px"></div>`).join('');
    box.innerHTML = `
      <div>${scores.length > 1 ? 'Improving · Score Delta +' + Math.max(0, scores[scores.length-1]-scores[0]) : 'First run captured'}</div>
      <div class="evolution-dots">${bars}</div>
    `;
  }

  const oldRender = window.render;
  if(typeof oldRender === 'function'){
    window.render = function(){
      const result = oldRender.apply(this, arguments);
      setTimeout(enhanceAfterRender, 80);
      return result;
    };
  }

  const input = document.getElementById('lyricInput');
  if(input){
    let pasteTimer = null;
    input.addEventListener('input', ()=>{
      clearTimeout(pasteTimer);
      const val = input.value.trim();
      if(val.length > 80 && !sessionStorage.getItem('zy_auto_hint_seen')){
        sessionStorage.setItem('zy_auto_hint_seen','1');
        pasteTimer = setTimeout(()=>{
          toast('Lyrics detected — click Run Full Chain to get scored options');
        }, 700);
      }
    });
  }
})();
</script>
'''

html = re.sub(r'<script id="guided-creation-loop-js">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", js + "\n</body>")

p.write_text(html, encoding="utf-8")
print("guided creation loop added")
PY

git add "$FILE"
git commit -m "Add guided creation loop to Music app" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=loop"
