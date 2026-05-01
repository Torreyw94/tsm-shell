#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/tsm-shell
FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.inlinestyle.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

new_render = """
<script>
(function(){
  function esc(v){ return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function money(n){ return '$'+Number(n||0).toLocaleString(); }

  async function renderDee(prompt){
    if(window.DEE_LOADING) return;
    window.DEE_LOADING = true;
    if(prompt) window.DEE_LAST_ACTION = prompt;
    const target = document.getElementById('dee-live-output');
    if(!target){ window.DEE_LOADING=false; return; }
    target.style.cssText = 'display:block!important;visibility:visible!important;opacity:1!important';
    target.innerHTML = '<div style="color:#9fdcc9;padding:10px">Loading...</div>';
    try {
      const res = await fetch('/api/strategist/hc/dee-action',{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({system:'HonorHealth',selectedOffice:window.DEE_SELECTED_OFFICE||'Scottsdale - Shea',prompt:prompt||''})
      });
      const d = await res.json();
      const l = d.layer2||{};
      const ab = d.actionBoard||{};
      const alerts = d.alerts||[];
      const actions = (ab.actions&&ab.actions.length)?ab.actions:[
        'Run denial recovery plan for '+(window.DEE_SELECTED_OFFICE||'Scottsdale - Shea'),
        'Escalate payer auth blockers for '+(window.DEE_SELECTED_OFFICE||'Scottsdale - Shea'),
        'Compare '+(window.DEE_SELECTED_OFFICE||'Scottsdale - Shea')+' vs best-performing office'
      ];
      target.innerHTML = `
        <div style="color:#00ffa3;font-weight:bold;margin-bottom:8px;padding:10px;border-left:3px solid #00ffa3">
          ${esc(ab.topPriorityNow||l.rootCause||'Intervene now')}
          <div style="font-size:11px;color:#9fdcc9;margin-top:6px">Last action: ${esc(window.DEE_LAST_ACTION)}</div>
        </div>
        <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:12px">
          <div style="background:#0a1f2e;padding:10px;border-radius:6px;text-align:center">${money(l.revenueAtRisk)}<br><span style="font-size:11px;color:#9fdcc9">Risk</span></div>
          <div style="background:#0a1f2e;padding:10px;border-radius:6px;text-align:center">${money(l.recoverable72h)}<br><span style="font-size:11px;color:#9fdcc9">Recoverable</span></div>
          <div style="background:#0a1f2e;padding:10px;border-radius:6px;text-align:center">${money(l.cashAcceleration14d)}<br><span style="font-size:11px;color:#9fdcc9">14d</span></div>
          <div style="background:#0a1f2e;padding:10px;border-radius:6px;text-align:center">${esc(l.highestYieldLane||'Insurance')}<br><span style="font-size:11px;color:#9fdcc9">Lane</span></div>
        </div>
        ${alerts.map(a=>`<div style="border-left:3px solid ${a.severity==='HIGH'?'#ff4444':'#ffaa00'};padding:8px;margin-bottom:6px;font-size:13px">${esc(a.type)}: ${esc(a.message)}</div>`).join('')}
        <div style="margin-top:12px;display:flex;flex-wrap:wrap;gap:8px">
          ${actions.map(a=>`<button onclick="window.quickAsk('${esc(a)}')" style="padding:8px 14px;background:#0a1f2e;color:#00ffa3;border:1px solid rgba(0,255,163,.4);border-radius:4px;cursor:pointer;font-family:monospace">${esc(a)}</button>`).join('')}
        </div>
      `;
    } catch(e){
      target.innerHTML = '<div style="color:#ff4444;padding:10px">Error: '+esc(e.message)+'</div>';
    } finally {
      window.DEE_LOADING = false;
    }
  }

  window.quickAsk = function(p){ return renderDee(p); };
  window.selectDeeOffice = function(o){ window.DEE_SELECTED_OFFICE=o; return renderDee('refresh for '+o); };
  window.DEE_SELECTED_OFFICE = window.DEE_SELECTED_OFFICE||'Scottsdale - Shea';
  window.DEE_LAST_ACTION = 'initial load';
  window.DEE_LOADING = false;

  window.addEventListener('load', function(){
    const t = document.getElementById('dee-live-output');
    if(t && !t.dataset.deeBooted){ t.dataset.deeBooted='1'; renderDee('initial load'); }
  });
})();
</script>
"""

# Remove all previous DEE controller scripts to avoid conflicts
import re
text = re.sub(r'<script>\s*\(function\(\)\{[\s\S]*?window\.DEE_LOADING\s*=\s*false;[\s\S]*?\}\)\(\);\s*</script>', '', text)

# Inject before </body>
text = text.replace('</body>', new_render + '\n</body>')

p.write_text(text, encoding='utf-8')
print("Done - replaced all Dee controllers with inline-style renderer")
PY

git add "$FILE"
git commit -m "Replace Dee renderer with inline-style version - no CSS class deps"
git push origin main
fly deploy
