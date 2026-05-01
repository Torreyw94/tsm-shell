#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.cleanrender.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1) Remove prior Dee render artifacts
text = re.sub(r'<style id="dee-command-cards-style">[\s\S]*?</style>', '', text)
text = re.sub(r'<style id="dee-command-upgrade-style">[\s\S]*?</style>', '', text)
text = re.sub(r'window\.selectDeeOffice\s*=\s*function\(office\)\{[\s\S]*?\};', '', text)
text = re.sub(r'window\.DEE_SELECTED_OFFICE\s*=.*?;', '', text)
text = re.sub(r'window\.quickAsk\s*=\s*async function\(promptText\)\s*\{[\s\S]*?\n\};', '', text)

clean_css = """
<style id="dee-clean-render-style">
#dee-live-output{
  margin-top:20px;
  padding:20px;
  border:1px solid rgba(0,255,163,.18);
  background:#06121c;
  color:#d9fff2;
  font-family:Inter,Arial,sans-serif;
  min-height:220px;
  border-radius:14px;
}
.dee-cards-wrap{display:grid;gap:16px}
.dee-card-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}
.dee-card{
  background:#081722;
  border:1px solid rgba(0,255,163,.14);
  border-radius:12px;
  padding:14px;
}
.dee-card-label{
  font-size:11px;
  letter-spacing:.14em;
  text-transform:uppercase;
  color:#7decc8;
  margin-bottom:8px;
}
.dee-card-value{
  font-size:28px;
  font-weight:800;
  color:#ffffff;
  line-height:1.1;
}
.dee-priority{
  border-left:4px solid #ffcc66;
  background:#0a1822;
  border-radius:12px;
  padding:16px;
}
.dee-priority-title{
  color:#ffcc66;
  font-size:12px;
  text-transform:uppercase;
  letter-spacing:.14em;
  margin-bottom:8px;
}
.dee-priority-body{
  font-size:22px;
  color:#fff;
  font-weight:800;
  line-height:1.25;
}
.dee-alerts{display:grid;gap:10px}
.dee-alert{
  background:#09141d;
  border:1px solid rgba(255,255,255,.08);
  border-left:4px solid #00ffa3;
  border-radius:10px;
  padding:12px;
}
.dee-alert.high{border-left-color:#ff6b6b}
.dee-alert.medium{border-left-color:#ffd166}
.dee-alert.low{border-left-color:#00ffa3}
.dee-alert-type{
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.12em;
  color:#8fd7bd;
  margin-bottom:6px;
}
.dee-alert-msg{font-size:14px;color:#fff}
.dee-section-title{
  font-size:11px;
  letter-spacing:.14em;
  text-transform:uppercase;
  color:#7decc8;
  margin-bottom:10px;
}
.dee-actions{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:10px;
}
.dee-btn{
  appearance:none;
  border:1px solid rgba(0,255,163,.18);
  background:#0a1822;
  color:#d9fff2;
  border-radius:10px;
  padding:12px 14px;
  text-align:left;
  cursor:pointer;
  font-size:13px;
  font-weight:700;
}
.dee-btn:hover{background:#0d1d28}
.dee-heatmap{
  display:grid;
  grid-template-columns:repeat(4,minmax(0,1fr));
  gap:10px;
}
.dee-heat{
  background:#09141d;
  border:1px solid rgba(255,255,255,.08);
  border-radius:10px;
  padding:12px;
  cursor:pointer;
}
.dee-heat:hover{background:#0c1922}
.dee-heat.high{border-left:4px solid #ff6b6b}
.dee-heat.stable{border-left:4px solid #00ffa3}
.dee-heat.medium{border-left:4px solid #ffd166}
.dee-heat-title{
  font-size:13px;
  font-weight:800;
  color:#fff;
  margin-bottom:6px;
}
.dee-heat-sub{
  font-size:12px;
  color:#9fdcc9;
  line-height:1.45;
}
.dee-meta{
  font-size:12px;
  color:#9fdcc9;
  margin-top:8px;
}
.dee-narrative{
  white-space:pre-wrap;
  background:#09141d;
  border:1px solid rgba(255,255,255,.08);
  border-radius:12px;
  padding:14px;
  color:#d9fff2;
  font-size:14px;
  line-height:1.55;
}
@media (max-width:1100px){
  .dee-card-grid,.dee-actions,.dee-heatmap{grid-template-columns:1fr 1fr}
}
@media (max-width:700px){
  .dee-card-grid,.dee-actions,.dee-heatmap{grid-template-columns:1fr}
}
</style>
"""

if 'dee-clean-render-style' not in text:
    text = text.replace('</head>', clean_css + '\n</head>')

clean_script = """
<script>
window.DEE_SELECTED_OFFICE = 'Scottsdale - Shea';

window.selectDeeOffice = function(office){
  window.DEE_SELECTED_OFFICE = office;
  return window.quickAsk('refresh command view for ' + office);
};

window.quickAsk = async function(promptText){
  try {
    const selectedOffice = window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea';

    const r = await fetch('/api/strategist/hc/dee-action', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({
        system: 'HonorHealth',
        selectedOffice: selectedOffice,
        prompt: promptText || ''
      })
    });

    const data = await r.json();

    const target = document.getElementById('dee-live-output') || document.body;
    const ab = data.actionBoard || {};
    const layer2 = data.layer2 || {};
    const alerts = data.alerts || [];
    const posture = data.posture || {};
    const ranking = posture.officeRanking || [];

    const esc = function(v){
      return String(v == null ? '' : v)
        .replace(/&/g,'&amp;')
        .replace(/</g,'&lt;')
        .replace(/>/g,'&gt;')
        .replace(/"/g,'&quot;');
    };

    const money = function(n){
      return '$' + Number(n || 0).toLocaleString();
    };

    const actions = (ab.actions && ab.actions.length) ? ab.actions : [
      'Run denial recovery plan for ' + selectedOffice,
      'Escalate payer auth blockers for ' + selectedOffice,
      'Generate executive brief for ' + selectedOffice
    ];

    const actionButtons = actions.map(function(a){
      return '<button class="dee-btn" data-action="' + esc(a) + '">' + esc(a) + '</button>';
    }).join('');

    const alertHtml = alerts.length ? alerts.map(function(a){
      const sev = String(a.severity || '').toLowerCase();
      return '<div class="dee-alert ' + esc(sev) + '">' +
        '<div class="dee-alert-type">' + esc(a.type) + ' · ' + esc(a.severity) + '</div>' +
        '<div class="dee-alert-msg">' + esc(a.message) + '</div>' +
      '</div>';
    }).join('') : '<div class="dee-alert low"><div class="dee-alert-msg">No active alerts</div></div>';

    const heatmap = ranking.map(function(o){
      return '<div class="dee-heat ' + esc(String(o.status || 'stable').toLowerCase()) + '" data-office="' + esc(o.office) + '">' +
        '<div class="dee-heat-title">' + esc(o.office) + '</div>' +
        '<div class="dee-heat-sub">Rank #' + esc(o.riskRank) + ' · Score ' + esc(o.riskScore) + '<br>' + esc(o.summary || '') + '</div>' +
      '</div>';
    }).join('');

    target.innerHTML =
      '<div class="dee-cards-wrap">' +

        '<div class="dee-priority">' +
          '<div class="dee-priority-title">Top Priority</div>' +
          '<div class="dee-priority-body">' + esc(ab.topPriorityNow || ('Intervene in ' + selectedOffice)) + '</div>' +
          '<div class="dee-meta">Selected Office: ' + esc(selectedOffice) + ' · Payer Focus: ' + esc(ab.payerFocus || 'Prior Authorization') + '</div>' +
        '</div>' +

        '<div class="dee-card">' +
          '<div class="dee-section-title">Immediate Actions</div>' +
          '<div class="dee-actions">' + actionButtons + '</div>' +
        '</div>' +

        '<div class="dee-card-grid">' +
          '<div class="dee-card"><div class="dee-card-label">Revenue At Risk</div><div class="dee-card-value">' + money(layer2.revenueAtRisk) + '</div></div>' +
          '<div class="dee-card"><div class="dee-card-label">Recoverable 72h</div><div class="dee-card-value">' + money(layer2.recoverable72h) + '</div></div>' +
          '<div class="dee-card"><div class="dee-card-label">14d Acceleration</div><div class="dee-card-value">' + money(layer2.cashAcceleration14d) + '</div></div>' +
          '<div class="dee-card"><div class="dee-card-label">Highest Yield Lane</div><div class="dee-card-value" style="font-size:22px">' + esc(layer2.highestYieldLane || 'Insurance') + '</div></div>' +
        '</div>' +

        '<div class="dee-card">' +
          '<div class="dee-section-title">Alert Stack</div>' +
          '<div class="dee-alerts">' + alertHtml + '</div>' +
        '</div>' +

        '<div class="dee-card">' +
          '<div class="dee-section-title">Office Heatmap</div>' +
          '<div class="dee-heatmap">' + heatmap + '</div>' +
        '</div>' +

        '<div class="dee-card">' +
          '<div class="dee-section-title">Strategist Narrative</div>' +
          '<div class="dee-narrative">' + esc(ab.strategistNarrative || '') + '</div>' +
        '</div>' +

      '</div>';

    Array.prototype.forEach.call(target.querySelectorAll('[data-action]'), function(btn){
      btn.onclick = function(){
        return window.quickAsk(btn.getAttribute('data-action'));
      };
    });

    Array.prototype.forEach.call(target.querySelectorAll('[data-office]'), function(tile){
      tile.onclick = function(){
        return window.selectDeeOffice(tile.getAttribute('data-office'));
      };
    });

    return data;
  } catch(e){
    console.error('quickAsk failed', e);
    return { ok:false, error:e.message };
  }
};
</script>
"""

if 'window.selectDeeOffice' not in text:
    text = text.replace('</body>', clean_script + '\n</body>')

p.write_text(text, encoding='utf-8')
print('Rebuilt Dee render clean')
PY

git add "$FILE"
git commit -m "Rebuild Dee render clean" || true
git push origin main || true
fly deploy
