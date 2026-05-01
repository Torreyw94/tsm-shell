#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/tsm-shell
FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.actiondetail.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

new_script = """
<script>
(function(){
  function esc(v){ return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function money(n){ return '$'+Number(n||0).toLocaleString(); }

  function renderActionDetail(ad) {
    if (!ad) return '';
    if (ad.view === 'denial' || ad.view === 'auth') {
      return `
        <div style="margin:12px 0;padding:10px;background:#0a1f2e;border-radius:6px;border-left:3px solid #00ffa3">
          <div style="color:#00ffa3;font-weight:bold;margin-bottom:8px">${esc(ad.title)}</div>
          ${ad.steps.map(s=>`<div style="padding:5px 0;border-bottom:1px solid rgba(0,255,163,.1);font-size:13px">${esc(s)}</div>`).join('')}
          ${ad.metric ? `<div style="margin-top:8px;font-size:12px;color:#9fdcc9">${esc(ad.metric.label)}: <span style="color:#00ffa3">${esc(ad.metric.value)}</span> → target ${esc(ad.metric.target)}</div>` : ''}
        </div>`;
    }
    if (ad.view === 'compare') {
      return `
        <div style="margin:12px 0;padding:10px;background:#0a1f2e;border-radius:6px;border-left:3px solid #ffaa00">
          <div style="color:#ffaa00;font-weight:bold;margin-bottom:8px">${esc(ad.title)}</div>
          <table style="width:100%;border-collapse:collapse;font-size:13px">
            <tr style="color:#9fdcc9;border-bottom:1px solid rgba(0,255,163,.2)">
              <td style="padding:4px">Metric</td>
              <td style="padding:4px;text-align:right">This Office</td>
              <td style="padding:4px;text-align:right">Best Office</td>
            </tr>
            ${(ad.comparison||[]).map(r=>`
              <tr style="border-bottom:1px solid rgba(0,255,163,.08)">
                <td style="padding:4px;color:#9fdcc9">${esc(r.label)}</td>
                <td style="padding:4px;text-align:right;color:#ff4444">${esc(r.selected)}</td>
                <td style="padding:4px;text-align:right;color:#00ffa3">${esc(r.best)}</td>
              </tr>`).join('')}
          </table>
        </div>`;
    }
    return '';
  }

  async function renderDee(prompt) {
    if (window.DEE_LOADING) return;
    window.DEE_LOADING = true;
    if (prompt) window.DEE_LAST_ACTION = prompt;
    const target = document.getElementById('dee-live-output');
    if (!target) { window.DEE_LOADING = false; return; }
    target.style.cssText = 'display:block!important;visibility:visible!important;opacity:1!important';
    target.innerHTML = '<div style="color:#9fdcc9;padding:10px">Loading...</div>';
    try {
      const res = await fetch('/api/strategist/hc/dee-action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          system: 'HonorHealth',
          selectedOffice: window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea',
          prompt: prompt || ''
        })
      });
      const d = await res.json();
      const l = d.layer2 || {};
      const ab = d.actionBoard || {};
      const alerts = d.alerts || [];
      const actions = (ab.actions && ab.actions.length) ? ab.actions : [
        'Run denial recovery plan for ' + (window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea'),
        'Escalate payer auth blockers for ' + (window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea'),
        'Compare ' + (window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea') + ' vs best-performing office'
      ];

      target.innerHTML = `
        <div style="color:#00ffa3;font-weight:bold;margin-bottom:8px;padding:10px;border-left:3px solid #00ffa3">
          ${esc(ab.topPriorityNow || 'Intervene now')}
          <div style="font-size:11px;color:#9fdcc9;margin-top:4px">Last action: ${esc(window.DEE_LAST_ACTION)}</div>
        </div>
        <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:12px">
          <div style="background:#0a1f2e;padding:10px;border-radius:6px;text-align:center">${money(l.revenueAtRisk)}<br><span style="font-size:11px;color:#9fdcc9">Risk</span></div>
          <div style="background:#0a1f2e;padding:10px;border-radius:6px;text-align:center">${money(l.recoverable72h)}<br><span style="font-size:11px;color:#9fdcc9">Recoverable</span></div>
          <div style="background:#0a1f2e;padding:10px;border-radius:6px;text-align:center">${money(l.cashAcceleration14d)}<br><span style="font-size:11px;color:#9fdcc9">14d</span></div>
          <div style="background:#0a1f2e;padding:10px;border-radius:6px;text-align:center">${esc(l.highestYieldLane||'Insurance')}<br><span style="font-size:11px;color:#9fdcc9">Lane</span></div>
        </div>
        ${renderActionDetail(d.actionDetail)}
        ${alerts.map(a=>`<div style="border-left:3px solid ${a.severity==='HIGH'?'#ff4444':'#ffaa00'};padding:8px;margin-bottom:6px;font-size:13px">${esc(a.type)}: ${esc(a.message)}</div>`).join('')}
        <div style="margin-top:12px;display:flex;flex-wrap:wrap;gap:8px">
          ${actions.map(a=>`<button onclick="window.quickAsk('${esc(a)}')" style="padding:8px 14px;background:#0a1f2e;color:#00ffa3;border:1px solid rgba(0,255,163,.4);border-radius:4px;cursor:pointer;font-family:monospace;font-size:12px">${esc(a)}</button>`).join('')}
        </div>
        <div style="margin-top:10px">
          <button onclick="window.quickAsk('initial load')" style="padding:6px 12px;background:transparent;color:#9fdcc9;border:1px solid rgba(159,220,201,.3);border-radius:4px;cursor:pointer;font-size:11px">↩ Back to overview</button>
        </div>
      `;
    } catch(e) {
      target.innerHTML = '<div style="color:#ff4444;padding:10px">Error: ' + esc(e.message) + '</div>';
    } finally {
      window.DEE_LOADING = false;
    }
  }

  window.quickAsk = function(p) { return renderDee(p); };
  window.selectDeeOffice = function(o) { window.DEE_SELECTED_OFFICE = o; return renderDee('refresh for ' + o); };
  window.DEE_SELECTED_OFFICE = window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea';
  window.DEE_LAST_ACTION = 'initial load';
  window.DEE_LOADING = false;

  window.addEventListener('load', function() {
    const t = document.getElementById('dee-live-output');
    if (t && !t.dataset.deeBooted) { t.dataset.deeBooted = '1'; renderDee('initial load'); }
  });
})();
</script>
"""

# Remove all previous DEE controller scripts
text = re.sub(r'<script>\s*\(function\(\)\{[\s\S]*?window\.DEE_LOADING\s*=\s*false;[\s\S]*?\}\)\(\);\s*</script>', '', text)
text = text.replace('</body>', new_script + '\n</body>')

p.write_text(text, encoding='utf-8')
print("Done - action detail renderer installed")
PY

git add "$FILE"
git commit -m "Render actionDetail per button - denial plan, auth escalation, compare table"
git push origin main
fly deploy
