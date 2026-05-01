#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.cardsbak.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

css = """
<style id="dee-command-cards-style">
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
.dee-actions{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}
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
@media (max-width: 1100px){
  .dee-card-grid,.dee-actions{grid-template-columns:1fr 1fr}
}
@media (max-width: 700px){
  .dee-card-grid,.dee-actions{grid-template-columns:1fr}
}
</style>
"""

if "dee-command-cards-style" not in text:
    text = text.replace("</head>", css + "\n</head>")

pattern = r"window\.quickAsk\s*=\s*async function\(promptText\)\s*\{[\s\S]*?\n\s*\};"
replacement = """
window.quickAsk = async function(promptText){
  try {
    const r = await fetch('/api/strategist/hc/dee-action', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({
        system: 'HonorHealth',
        selectedOffice: 'Scottsdale - Shea',
        prompt: promptText || ''
      })
    });

    const data = await r.json();

    const target = document.getElementById('dee-live-output') || document.body;
    const ab = data.actionBoard || {};
    const layer2 = data.layer2 || {};
    const alerts = data.alerts || [];

    const esc = (v) => String(v ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    const money = (n) => '$' + Number(n || 0).toLocaleString();

    target.innerHTML = `
      <div class="dee-cards-wrap">
        <div class="dee-priority">
          <div class="dee-priority-title">Top Priority</div>
          <div class="dee-priority-body">${esc(ab.topPriorityNow || 'Intervene in Scottsdale - Shea')}</div>
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
          <div class="dee-card-label">Alert Stack</div>
          <div class="dee-alerts">
            ${alerts.map(a => `
              <div class="dee-alert ${String(a.severity || '').toLowerCase()}">
                <div class="dee-alert-type">${esc(a.type)} · ${esc(a.severity)}</div>
                <div class="dee-alert-msg">${esc(a.message)}</div>
              </div>
            `).join('') || '<div class="dee-alert low"><div class="dee-alert-msg">No active alerts</div></div>'}
          </div>
        </div>

        <div class="dee-card">
          <div class="dee-card-label">Strategist Narrative</div>
          <div class="dee-narrative">${esc(ab.strategistNarrative || '')}</div>
        </div>

        <div class="dee-card">
          <div class="dee-card-label">Actions</div>
          <div class="dee-actions">
            <button class="dee-btn" onclick="quickAsk('run denial recovery plan for Scottsdale - Shea')">Run Recovery Plan</button>
            <button class="dee-btn" onclick="quickAsk('escalate payer auth blockers for Scottsdale - Shea')">Escalate Payer</button>
            <button class="dee-btn" onclick="quickAsk('generate executive brief for Dee Montee on Scottsdale Shea revenue posture')">Generate Brief</button>
          </div>
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
print("Converted Dee output into command cards")
PY

git add "$FILE"
git commit -m "Convert Dee output into command cards" || true
git push origin main || true
fly deploy
