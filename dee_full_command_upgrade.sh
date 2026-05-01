#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.fullcmd.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1) Add extra CSS once
extra_css = """
<style id="dee-command-upgrade-style">
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
@media (max-width:1100px){
  .dee-actions,.dee-heatmap{grid-template-columns:1fr 1fr}
}
@media (max-width:700px){
  .dee-actions,.dee-heatmap{grid-template-columns:1fr}
}
</style>
"""
if "dee-command-upgrade-style" not in text:
    text = text.replace("</head>", extra_css + "\n</head>")

# 2) Add office switching helpers once
helper = """
<script>
window.DEE_SELECTED_OFFICE = window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea';
window.selectDeeOffice = function(office){
  window.DEE_SELECTED_OFFICE = office;
  return window.quickAsk('refresh command view for ' + office);
};
</script>
"""
if "window.selectDeeOffice" not in text:
    text = text.replace("</body>", helper + "\n</body>")

# 3) Replace current quickAsk with richer version
pattern = r"window\.quickAsk\s*=\s*async function\(promptText\)\s*\{[\s\S]*?\n\};"
replacement = r"""
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

    const esc = (v) => String(v ?? '')
      .replace(/&/g,'&amp;')
      .replace(/</g,'&lt;')
      .replace(/>/g,'&gt;')
      .replace(/"/g,'&quot;');

    const money = (n) => '$' + Number(n || 0).toLocaleString();

    const actionButtons = (ab.actions || []).map(a => `
      <button class="dee-btn" onclick="quickAsk(${JSON.stringify(a)})">${esc(a)}</button>
    `).join('');

    const heatmap = ranking.map(o => `
      <div class="dee-heat ${esc((o.status || 'stable').toLowerCase())}" onclick="selectDeeOffice(${JSON.stringify(o.office)})">
        <div class="dee-heat-title">${esc(o.office)}</div>
        <div class="dee-heat-sub">
          Rank #${esc(o.riskRank)} · Score ${esc(o.riskScore)}<br>
          ${esc(o.summary || '')}
        </div>
      </div>
    `).join('');

    target.innerHTML = `
      <div class="dee-cards-wrap">

        <div class="dee-priority">
          <div class="dee-priority-title">Top Priority</div>
          <div class="dee-priority-body">${esc(ab.topPriorityNow || 'Intervene in ' + selectedOffice)}</div>
          <div class="dee-meta">Selected Office: ${esc(selectedOffice)} · Payer Focus: ${esc(ab.payerFocus || 'Prior Authorization')}</div>
        </div>

        <div class="dee-card">
          <div class="dee-section-title">Immediate Actions</div>
          <div class="dee-actions">
            ${actionButtons || `
              <button class="dee-btn" onclick="quickAsk('run denial recovery plan for ${esc(selectedOffice)}')">Run Recovery Plan</button>
              <button class="dee-btn" onclick="quickAsk('escalate payer auth blockers for ${esc(selectedOffice)}')">Escalate Payer</button>
              <button class="dee-btn" onclick="quickAsk('generate executive brief for ${esc(selectedOffice)}')">Generate Brief</button>
            `}
          </div>
        </div>

        <div class="dee-card-grid">
          <div class="dee-card">
            <div class="dee-card-label">Revenue At Risk</div>
            <div class="dee-card-value">${money(layer2.revenueAtRisk)}</div>
          </div>
          <div class="dee-card">
            <div class="dee-card-label">Recoverable 72h</div>
            <div class="dee-card-value">${money(layer2.recoverable72h)}</div>
          </div>
          <div class="dee-card">
            <div class="dee-card-label">14d Acceleration</div>
            <div class="dee-card-value">${money(layer2.cashAcceleration14d)}</div>
          </div>
          <div class="dee-card">
            <div class="dee-card-label">Highest Yield Lane</div>
            <div class="dee-card-value" style="font-size:22px">${esc(layer2.highestYieldLane || 'Insurance')}</div>
          </div>
        </div>

        <div class="dee-card">
          <div class="dee-section-title">Alert Stack</div>
          <div class="dee-alerts">
            ${alerts.map(a => `
              <div class="dee-alert ${esc(String(a.severity || '').toLowerCase())}">
                <div class="dee-alert-type">${esc(a.type)} · ${esc(a.severity)}</div>
                <div class="dee-alert-msg">${esc(a.message)}</div>
              </div>
            `).join('') || '<div class="dee-alert low"><div class="dee-alert-msg">No active alerts</div></div>'}
          </div>
        </div>

        <div class="dee-card">
          <div class="dee-section-title">Office Heatmap</div>
          <div class="dee-heatmap">
            ${heatmap}
          </div>
        </div>

        <div class="dee-card">
          <div class="dee-section-title">Strategist Narrative</div>
          <div class="dee-narrative">${esc(ab.strategistNarrative || '')}</div>
        </div>
      </div>
    `;

    return data;
  } catch(e){
    console.error('quickAsk failed', e);
    return { ok:false, error:e.message };
  }
};"""
text, count = re.subn(pattern, replacement, text, count=1)
if count == 0:
    raise SystemExit("Could not find quickAsk function to replace")

p.write_text(text, encoding="utf-8")
print("Dee full command upgrade applied")
PY

git add "$FILE"
git commit -m "Upgrade Dee into full command surface" || true
git push origin main || true
fly deploy
