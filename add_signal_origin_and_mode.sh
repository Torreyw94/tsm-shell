#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.signalmode.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1) Add CSS once
css = """
<style id="dee-signal-mode-style">
.chain-bar{
  display:grid;
  grid-template-columns:1.2fr .9fr .9fr 1fr;
  gap:10px;
  margin-top:14px;
}
.chain-box{
  background:#09141d;
  border:1px solid rgba(255,255,255,.08);
  border-radius:10px;
  padding:12px;
}
.chain-label{
  font-size:10px;
  letter-spacing:.14em;
  text-transform:uppercase;
  color:#7decc8;
  margin-bottom:8px;
}
.chain-value{
  font-size:13px;
  color:#fff;
  line-height:1.45;
}
.mode-pill{
  display:inline-flex;
  align-items:center;
  gap:6px;
  padding:6px 10px;
  border-radius:999px;
  border:1px solid rgba(173,123,255,.28);
  background:rgba(173,123,255,.08);
  color:#d8c7ff;
  font-size:11px;
  letter-spacing:.12em;
  text-transform:uppercase;
}
.origin-grid{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:10px;
}
.origin-card{
  background:#09141d;
  border:1px solid rgba(255,255,255,.08);
  border-left:4px solid #00ffa3;
  border-radius:10px;
  padding:12px;
}
.origin-card.billing{border-left-color:#ff6b6b}
.origin-card.insurance{border-left-color:#ffd166}
.origin-card.operations{border-left-color:#56d7ff}
.origin-head{
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.12em;
  color:#8fd7bd;
  margin-bottom:6px;
}
.origin-body{
  font-size:13px;
  color:#fff;
  line-height:1.45;
}
.link-strip{
  display:flex;
  flex-wrap:wrap;
  gap:10px;
  margin-top:10px;
}
.link-chip{
  padding:8px 10px;
  border-radius:10px;
  border:1px solid rgba(0,255,163,.18);
  background:#0a1822;
  color:#d9fff2;
  font-size:12px;
}
@media (max-width:1100px){
  .chain-bar,.origin-grid{grid-template-columns:1fr 1fr}
}
@media (max-width:700px){
  .chain-bar,.origin-grid{grid-template-columns:1fr}
}
</style>
"""
if "dee-signal-mode-style" not in text:
    text = text.replace("</head>", css + "\n</head>")

# 2) Inject helper functions + enhanced render
marker = "function renderWarRoom(data){"
if marker in text and "function deriveStrategistMode" not in text:
    helper = """
    function deriveStrategistMode(lastAction){
      const a = String(lastAction || '').toLowerCase();
      if (a.includes('brief')) return 'Executive Summary';
      if (a.includes('payer') || a.includes('auth')) return 'Payer Intervention';
      if (a.includes('compare')) return 'Office Comparison';
      if (a.includes('recovery') || a.includes('denial')) return 'Revenue Recovery';
      if (a.includes('priority')) return 'Priority Action';
      return 'Command Review';
    }

    function deriveSignalOrigin(data){
      const selected = window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea';
      const alerts = data.alerts || [];
      const origin = [];

      const hasBilling = alerts.some(a => String(a.type || '').toLowerCase().includes('denial'));
      const hasInsurance = alerts.some(a => String(a.type || '').toLowerCase().includes('auth'));
      const hasOps = alerts.some(a => String(a.type || '').toLowerCase().includes('queue'));

      if (hasBilling) {
        const denial = alerts.find(a => String(a.type || '').toLowerCase().includes('denial'));
        origin.push({
          lane:'billing',
          title:'Billing Signal',
          body:(denial && denial.message) || (selected + ': denial pressure detected')
        });
      }
      if (hasInsurance) {
        const auth = alerts.find(a => String(a.type || '').toLowerCase().includes('auth'));
        origin.push({
          lane:'insurance',
          title:'Insurance Signal',
          body:(auth && auth.message) || (selected + ': auth delays detected')
        });
      }
      if (hasOps) {
        const q = alerts.find(a => String(a.type || '').toLowerCase().includes('queue'));
        origin.push({
          lane:'operations',
          title:'Operations Signal',
          body:(q && q.message) || (selected + ': queue pressure detected')
        });
      }

      if (!origin.length) {
        origin.push(
          {lane:'billing', title:'Billing Signal', body:selected + ': denial monitoring active'},
          {lane:'insurance', title:'Insurance Signal', body:selected + ': payer/auth review active'},
          {lane:'operations', title:'Operations Signal', body:selected + ': intake/throughput review active'}
        );
      }

      return origin.slice(0,3);
    }
"""
    text = text.replace(marker, helper + "\n\n" + marker, 1)

# 3) Expand renderWarRoom output by inserting signal/mode blocks after priority
old = """        <div class="priority">
          <div class="priority-title">Top Priority</div>
          <div class="priority-body">${esc(ab.topPriorityNow || ('Intervene in ' + window.DEE_SELECTED_OFFICE))}</div>
          <div class="meta">
            Selected Office: ${esc(window.DEE_SELECTED_OFFICE)} ·
            Last Action: ${esc(window.DEE_LAST_ACTION)} ·
            Payer Focus: ${esc(ab.payerFocus || 'Prior Authorization')}
          </div>
        </div>"""

new = """        <div class="priority">
          <div class="priority-title">Top Priority</div>
          <div class="priority-body">${esc(ab.topPriorityNow || ('Intervene in ' + window.DEE_SELECTED_OFFICE))}</div>
          <div class="meta">
            Selected Office: ${esc(window.DEE_SELECTED_OFFICE)} ·
            Last Action: ${esc(window.DEE_LAST_ACTION)} ·
            Payer Focus: ${esc(ab.payerFocus || 'Prior Authorization')}
          </div>
          <div class="link-strip">
            <div class="link-chip">Healthcare Command → live node state</div>
            <div class="link-chip">HC Strategist → healthcare reasoning</div>
            <div class="link-chip">Main Strategist → priority synthesis</div>
            <div class="link-chip">Dee → execution surface</div>
          </div>
        </div>

        <div class="chain-bar">
          <div class="chain-box">
            <div class="chain-label">Strategist Mode</div>
            <div class="chain-value"><span class="mode-pill">${esc(deriveStrategistMode(window.DEE_LAST_ACTION))}</span></div>
          </div>
          <div class="chain-box">
            <div class="chain-label">Primary Office</div>
            <div class="chain-value">${esc(window.DEE_SELECTED_OFFICE)}</div>
          </div>
          <div class="chain-box">
            <div class="chain-label">System Link</div>
            <div class="chain-value">HC Command → HC Strategist → Main Strategist → Dee</div>
          </div>
          <div class="chain-box">
            <div class="chain-label">Reasoning Scope</div>
            <div class="chain-value">Signals → Interpretation → Priority → Action</div>
          </div>
        </div>

        <div class="section" style="margin-top:14px;padding:14px">
          <div class="section-title">Signal Origin</div>
          <div class="origin-grid">
            ${deriveSignalOrigin(data).map(s => `
              <div class="origin-card ${esc(s.lane)}">
                <div class="origin-head">${esc(s.title)}</div>
                <div class="origin-body">${esc(s.body)}</div>
              </div>
            `).join('')}
          </div>
        </div>"""

if old in text:
    text = text.replace(old, new, 1)

p.write_text(text, encoding="utf-8")
print("Signal origin + strategist mode UI added")
PY

git add "$FILE"
git commit -m "Add signal origin and strategist mode UI to Dee war room" || true
git push origin main || true
fly deploy
