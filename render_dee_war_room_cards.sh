#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.warrender.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

css = """
<style id="dee-war-room-render-style">
#dee-live-inner{display:grid;gap:14px}
.dee-priority{
  border-left:4px solid #ffcc66;
  background:#0a1822;
  border-radius:12px;
  padding:16px;
  color:#fff;
}
.dee-priority-title{
  color:#ffcc66;
  font-size:11px;
  letter-spacing:.14em;
  text-transform:uppercase;
  margin-bottom:8px;
}
.dee-priority-body{
  font-size:22px;
  font-weight:800;
  line-height:1.25;
}
.dee-meta{
  font-size:12px;
  color:#9fdcc9;
  margin-top:8px;
}
.dee-kpis{
  display:grid;
  grid-template-columns:repeat(4,minmax(0,1fr));
  gap:12px;
}
.dee-kpi{
  background:#081722;
  border:1px solid rgba(0,255,163,.14);
  border-radius:12px;
  padding:14px;
  color:#fff;
}
.dee-kpi-label{
  font-size:11px;
  letter-spacing:.14em;
  text-transform:uppercase;
  color:#7decc8;
  margin-bottom:8px;
}
.dee-kpi-value{
  font-size:28px;
  font-weight:800;
  line-height:1.1;
}
.dee-block{
  background:#081722;
  border:1px solid rgba(0,255,163,.14);
  border-radius:12px;
  padding:14px;
}
.dee-block-title{
  font-size:11px;
  letter-spacing:.14em;
  text-transform:uppercase;
  color:#7decc8;
  margin-bottom:10px;
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
.dee-alert-head{
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.12em;
  color:#8fd7bd;
  margin-bottom:6px;
}
.dee-alert-msg{font-size:14px;color:#fff}
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
.dee-btn:disabled{
  opacity:.55;
  cursor:not-allowed;
}
.dee-btn:hover{background:#0d1d28}
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
.dee-offices{
  display:grid;
  grid-template-columns:repeat(4,minmax(0,1fr));
  gap:10px;
}
.dee-office{
  background:#09141d;
  border:1px solid rgba(255,255,255,.08);
  border-left:4px solid #00ffa3;
  border-radius:10px;
  padding:12px;
  cursor:pointer;
}
.dee-office.high{border-left-color:#ff6b6b}
.dee-office.medium{border-left-color:#ffd166}
.dee-office.stable{border-left-color:#00ffa3}
.dee-office-name{
  font-size:13px;
  font-weight:800;
  color:#fff;
  margin-bottom:6px;
}
.dee-office-sub{
  font-size:12px;
  color:#9fdcc9;
  line-height:1.45;
}
@media (max-width:1100px){
  .dee-kpis,.dee-actions,.dee-offices{grid-template-columns:1fr 1fr}
}
@media (max-width:700px){
  .dee-kpis,.dee-actions,.dee-offices{grid-template-columns:1fr}
}
</style>
"""

if "dee-war-room-render-style" not in text:
    text = text.replace("</head>", css + "\n</head>")

script = r"""
<script>
window.DEE_SELECTED_OFFICE = window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea';
window.DEE_LAST_ACTION = window.DEE_LAST_ACTION || 'initial load';
window.DEE_LOADING = false;

function deeEsc(v){
  return String(v == null ? '' : v)
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;');
}
function deeMoney(n){
  return '$' + Number(n || 0).toLocaleString();
}

function renderDeeWarRoom(data){
  const out = document.getElementById('dee-live-inner');
  if(!out) return;

  const ab = data.actionBoard || {};
  const l = data.layer2 || {};
  const alerts = data.alerts || [];
  const posture = data.posture || data.systemPosture || {};
  const ranking = posture.officeRanking || data.officeRanking || [];
  const actions = (ab.actions && ab.actions.length) ? ab.actions : [
    'Run denial recovery plan for ' + window.DEE_SELECTED_OFFICE,
    'Escalate payer auth blockers for ' + window.DEE_SELECTED_OFFICE,
    'Generate executive brief for ' + window.DEE_SELECTED_OFFICE
  ];

  const alertHtml = alerts.length ? alerts.map(function(a){
    const sev = String(a.severity || '').toLowerCase();
    return `
      <div class="dee-alert ${deeEsc(sev)}">
        <div class="dee-alert-head">${deeEsc(a.type)} · ${deeEsc(a.severity)}</div>
        <div class="dee-alert-msg">${deeEsc(a.message)}</div>
      </div>
    `;
  }).join('') : '<div class="dee-alert low"><div class="dee-alert-msg">No active alerts</div></div>';

  const officeHtml = ranking.length ? ranking.map(function(o){
    const status = String(o.status || 'stable').toLowerCase();
    return `
      <div class="dee-office ${deeEsc(status)}" data-dee-office="${deeEsc(o.office)}">
        <div class="dee-office-name">${deeEsc(o.office)}</div>
        <div class="dee-office-sub">
          Rank #${deeEsc(o.riskRank || '')} · Score ${deeEsc(o.riskScore || '')}<br>
          ${deeEsc(o.summary || '')}
        </div>
      </div>
    `;
  }).join('') : `
      <div class="dee-office medium" data-dee-office="Scottsdale - Shea">
        <div class="dee-office-name">Scottsdale - Shea</div>
        <div class="dee-office-sub">Selected command office</div>
      </div>
    `;

  out.innerHTML = `
    <div class="dee-priority">
      <div class="dee-priority-title">Top Priority</div>
      <div class="dee-priority-body">${deeEsc(ab.topPriorityNow || ('Intervene in ' + window.DEE_SELECTED_OFFICE))}</div>
      <div class="dee-meta">
        Selected Office: ${deeEsc(window.DEE_SELECTED_OFFICE)} ·
        Last Action: ${deeEsc(window.DEE_LAST_ACTION)} ·
        Payer Focus: ${deeEsc(ab.payerFocus || 'Prior Authorization')}
      </div>
    </div>

    <div class="dee-kpis">
      <div class="dee-kpi">
        <div class="dee-kpi-label">Revenue At Risk</div>
        <div class="dee-kpi-value">${deeMoney(l.revenueAtRisk)}</div>
      </div>
      <div class="dee-kpi">
        <div class="dee-kpi-label">Recoverable 72h</div>
        <div class="dee-kpi-value">${deeMoney(l.recoverable72h)}</div>
      </div>
      <div class="dee-kpi">
        <div class="dee-kpi-label">14d Acceleration</div>
        <div class="dee-kpi-value">${deeMoney(l.cashAcceleration14d)}</div>
      </div>
      <div class="dee-kpi">
        <div class="dee-kpi-label">Highest Yield Lane</div>
        <div class="dee-kpi-value" style="font-size:22px">${deeEsc(l.highestYieldLane || 'Insurance')}</div>
      </div>
    </div>

    <div class="dee-block">
      <div class="dee-block-title">Immediate Actions</div>
      <div class="dee-actions">
        ${actions.map(function(a){
          return `<button class="dee-btn" type="button" data-dee-action="${deeEsc(a)}">${deeEsc(a)}</button>`;
        }).join('')}
      </div>
    </div>

    <div class="dee-block">
      <div class="dee-block-title">Alert Stack</div>
      <div class="dee-alerts">${alertHtml}</div>
    </div>

    <div class="dee-block">
      <div class="dee-block-title">Office Heatmap</div>
      <div class="dee-offices">${officeHtml}</div>
    </div>

    <div class="dee-block">
      <div class="dee-block-title">Strategist Narrative</div>
      <div class="dee-narrative">${deeEsc(ab.strategistNarrative || '')}</div>
    </div>
  `;

  out.querySelectorAll('[data-dee-action]').forEach(function(btn){
    btn.addEventListener('click', function(){
      quickAsk(this.getAttribute('data-dee-action'));
    });
  });

  out.querySelectorAll('[data-dee-office]').forEach(function(tile){
    tile.addEventListener('click', function(){
      window.DEE_SELECTED_OFFICE = this.getAttribute('data-dee-office');
      quickAsk('refresh command view for ' + window.DEE_SELECTED_OFFICE);
    });
  });
}

async function runDeeAction(prompt){
  const out = document.getElementById('dee-live-inner');
  if(!out || window.DEE_LOADING) return;

  window.DEE_LOADING = true;
  window.DEE_LAST_ACTION = prompt || 'initial load';
  out.innerHTML = '<div class="dee-narrative">Running AI for: ' + deeEsc(window.DEE_LAST_ACTION) + '</div>';

  try{
    const res = await fetch('/api/strategist/hc/dee-action', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        system:'HonorHealth',
        selectedOffice: window.DEE_SELECTED_OFFICE,
        prompt: prompt || ''
      })
    });

    const data = await res.json();
    renderDeeWarRoom(data);
    return data;
  } catch(e){
    out.innerHTML = '<div class="dee-alert high"><div class="dee-alert-msg">AI request failed: ' + deeEsc(e.message) + '</div></div>';
  } finally {
    window.DEE_LOADING = false;
  }
}

window.quickAsk = function(promptText){
  return runDeeAction(promptText || '');
};
window.openBriefing = function(){
  return runDeeAction('Generate a full team briefing for HonorHealth revenue cycle');
};
window.runQuickPack = function(kind){
  const prompt = kind === 'priority'
    ? 'Return the top priority action for HonorHealth revenue cycle right now'
    : 'Run denial recovery strategy for ' + window.DEE_SELECTED_OFFICE;
  return runDeeAction(prompt);
};
window.showTab = function(tab){
  document.querySelectorAll('[id^="tab-"]').forEach(function(el){ el.style.display = 'none'; });
  const target = document.getElementById('tab-' + tab);
  if (target) target.style.display = 'block';
};

window.addEventListener('load', function(){
  if (document.getElementById('dee-live-inner')) {
    runDeeAction('initial load');
  }
});
</script>
"""

if "function renderDeeWarRoom(data)" not in text:
    text = text.replace("</body>", script + "\n</body>")

p.write_text(text, encoding="utf-8")
print("Dee war room renderer injected")
PY

git add "$FILE"
git commit -m "Render strategist output as war room cards" || true
git push origin main || true
fly deploy
