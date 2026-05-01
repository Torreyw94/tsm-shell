#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/dee_command_center
cp -f "$FILE" "backups/dee_command_center/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# Remove earlier lightweight render injection if present
text = re.sub(
    r"<script>\s*window\.DEENEURAL\s*=\s*\{[\s\S]*?setTimeout\(\(\)=>window\.DEENEURAL\.load\(\)\.catch\(console\.error\),500\);\s*</script>",
    "",
    text,
    flags=re.S
)

inject = r"""
<style>
#dee-command-center{
  margin:18px 0 24px 0;
  border:1px solid rgba(255,255,255,.08);
  border-radius:16px;
  background:rgba(7,14,28,.82);
  padding:16px;
  color:#d9e7ff;
}
#dee-command-center .dcc-title{
  display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;
  margin-bottom:14px;padding-bottom:10px;border-bottom:1px solid rgba(255,255,255,.06);
}
#dee-command-center .dcc-kpis{
  display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:10px;margin-bottom:14px;
}
#dee-command-center .dcc-kpi{
  border:1px solid rgba(255,255,255,.08);border-radius:12px;background:rgba(255,255,255,.03);padding:10px;
}
#dee-command-center .dcc-kpi .lab{
  font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:#8fb3ff;margin-bottom:6px;
}
#dee-command-center .dcc-kpi .val{
  font-size:20px;font-weight:700;color:#ffffff;
}
#dee-command-center .dcc-grid{
  display:grid;grid-template-columns:1.15fr 1fr .9fr;gap:14px;
}
#dee-command-center .dcc-card{
  border:1px solid rgba(255,255,255,.08);border-radius:14px;background:rgba(255,255,255,.03);padding:12px;
}
#dee-command-center .dcc-head{
  font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:#8fb3ff;margin-bottom:10px;
}
#dee-command-center .dcc-pre{
  white-space:pre-wrap;line-height:1.7;font-size:13px;
}
#dee-command-center .dcc-list{
  display:grid;gap:8px;
}
#dee-command-center .dcc-item{
  display:flex;justify-content:space-between;gap:12px;padding:8px 10px;border:1px solid rgba(255,255,255,.06);
  border-radius:10px;background:rgba(255,255,255,.02);font-size:13px;
}
#dee-command-center .dcc-rank-critical{color:#ff8f8f}
#dee-command-center .dcc-rank-high{color:#ffcb7d}
#dee-command-center .dcc-rank-medium{color:#9fd0ff}
#dee-command-center .dcc-rank-stable{color:#92f0b2}
#dee-command-center .dcc-actions{
  display:flex;flex-wrap:wrap;gap:8px;margin-top:12px;
}
#dee-command-center .dcc-btn{
  border:1px solid rgba(255,255,255,.10);background:rgba(255,255,255,.04);color:#d9e7ff;
  border-radius:999px;padding:8px 12px;font-size:12px;cursor:pointer;
}
#dee-command-center .dcc-btn:hover{background:rgba(255,255,255,.08)}
#dee-command-center .dcc-alert{
  padding:8px 10px;border:1px solid rgba(255,255,255,.06);border-radius:10px;background:rgba(255,255,255,.02);font-size:13px;
}
#dee-command-center .dcc-sub{
  font-size:12px;color:#9fb4d9;
}
@media (max-width: 1180px){
  #dee-command-center .dcc-kpis{grid-template-columns:repeat(3,minmax(0,1fr))}
  #dee-command-center .dcc-grid{grid-template-columns:1fr}
}
</style>

<script>
window.DEECC = {
  system: 'HonorHealth',
  selectedOffice: 'Scottsdale - Shea',
  offices: ['Scottsdale - Shea','Mesa','Tempe','North Mountain'],

  money(v){
    return '$' + Number(v || 0).toLocaleString();
  },

  async post(url, body){
    const r = await fetch(url,{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify(body)
    });
    const t = await r.text();
    if(t.startsWith('<!DOCTYPE') || t.startsWith('<html')){
      throw new Error('HTML fallback from ' + url);
    }
    return JSON.parse(t);
  },

  async load(){
    const payload = await this.post('/api/honor/dee/dashboard', {
      system: this.system,
      selectedOffice: this.selectedOffice,
      offices: this.offices
    });

    if(!payload || !payload.ok) throw new Error(payload?.error || 'Dashboard load failed');

    this.render(payload);
    this.bindPrimaryButtons(payload);
    return payload;
  },

  ensureShell(){
    let shell = document.getElementById('dee-command-center');
    if(shell) return shell;

    shell = document.createElement('section');
    shell.id = 'dee-command-center';
    shell.innerHTML = `
      <div class="dcc-title">
        <div>
          <div class="dcc-head">HonorHealth Revenue Cycle Command</div>
          <div class="dcc-sub" id="dcc-subtitle">Dee Montee · Revenue Cycle Manager · Live multi-office posture</div>
        </div>
        <div class="dcc-sub" id="dcc-updated">Syncing...</div>
      </div>

      <div class="dcc-kpis" id="dcc-kpis"></div>

      <div class="dcc-grid">
        <div class="dcc-card">
          <div class="dcc-head">Selected Office Live State</div>
          <div class="dcc-pre" id="dcc-office-state">Loading office state...</div>
        </div>

        <div class="dcc-card">
          <div class="dcc-head">Dee Action Board</div>
          <div class="dcc-pre" id="dcc-action-board">Loading command board...</div>
          <div class="dcc-actions">
            <button class="dcc-btn" id="dcc-refresh">Refresh</button>
            <button class="dcc-btn" id="dcc-cfo">Generate CFO Brief</button>
            <button class="dcc-btn" id="dcc-variance">Run Office Variance</button>
            <button class="dcc-btn" id="dcc-mesa">Mesa Deep Dive</button>
          </div>
        </div>

        <div class="dcc-card">
          <div class="dcc-head">System Posture + Ranking</div>
          <div class="dcc-list" id="dcc-ranking"></div>
        </div>
      </div>

      <div class="dcc-grid" style="margin-top:14px;">
        <div class="dcc-card">
          <div class="dcc-head">Alerts</div>
          <div class="dcc-list" id="dcc-alerts"></div>
        </div>

        <div class="dcc-card">
          <div class="dcc-head">Executive Brief</div>
          <div class="dcc-pre" id="dcc-brief">Loading brief...</div>
        </div>

        <div class="dcc-card">
          <div class="dcc-head">Office Selector</div>
          <div class="dcc-list" id="dcc-offices"></div>
        </div>
      </div>
    `;

    const anchor =
      document.querySelector('#honor-neural-panel') ||
      document.querySelector('[data-email="brief"]')?.parentElement?.parentElement ||
      document.body;

    anchor.parentElement.insertBefore(shell, anchor.nextSibling);
    return shell;
  },

  render(payload){
    this.ensureShell();

    const selected = payload.selectedOfficeData || {};
    const state = selected.state || {};
    const layer2 = selected.layer2 || {};
    const brief = selected.brief || {};
    const posture = payload.systemPosture || {};
    const sp = posture.systemPosture || {};
    const rank = posture.officeRanking || [];
    const board = posture.deeActionBoard || {};
    const alerts = payload.alerts?.alerts || [];

    document.getElementById('dcc-updated').textContent =
      'Last sync: ' + new Date(payload.generatedAt || Date.now()).toLocaleString();

    document.getElementById('dcc-subtitle').textContent =
      `${payload.persona?.name || 'Dee Montee'} · ${payload.persona?.role || 'Revenue Cycle Manager'} · Selected office: ${payload.selectedOffice || this.selectedOffice}`;

    document.getElementById('dcc-kpis').innerHTML = `
      <div class="dcc-kpi"><div class="lab">Selected Office Risk</div><div class="val">${this.money(layer2.revenueAtRisk)}</div></div>
      <div class="dcc-kpi"><div class="lab">72H Recoverable</div><div class="val">${this.money(layer2.recoverable72h)}</div></div>
      <div class="dcc-kpi"><div class="lab">14D Acceleration</div><div class="val">${this.money(layer2.cashAcceleration14d)}</div></div>
      <div class="dcc-kpi"><div class="lab">Highest Yield Lane</div><div class="val">${layer2.highestYieldLane || '—'}</div></div>
      <div class="dcc-kpi"><div class="lab">Top Risk Office</div><div class="val">${sp.topRiskOffice || '—'}</div></div>
      <div class="dcc-kpi"><div class="lab">System Risk Total</div><div class="val">${this.money(sp.revenueAtRiskTotal)}</div></div>
    `;

    const ops = state.operations || {};
    const billing = state.billing || {};
    const insurance = state.insurance || {};
    document.getElementById('dcc-office-state').textContent =
`OPERATIONS
Queue: ${ops.queueDepth || 0}
Intake Backlog: ${ops.intakeBacklog || 0}
Staffing: ${ops.staffingCoverage || 0}%
Findings: ${ops.findings || '—'}

BILLING
Denial Rate: ${billing.denialRate || 0}%
Claim Lag: ${billing.claimLagDays || 0}d
AR > 30: ${this.money(billing.arOver30)}
Findings: ${billing.findings || '—'}

INSURANCE
Auth Backlog: ${insurance.authBacklog || 0}
Auth Delay: ${insurance.authDelayHours || 0}h
Pending Claims: ${this.money(insurance.pendingClaimsValue)}
Findings: ${insurance.findings || '—'}

BNCA ROOT CAUSE
- ${(layer2.rootCause || []).join('\n- ')}

BEST NEXT ACTIONS
1. ${(layer2.bestNextActions || [])[0] || '—'}
2. ${(layer2.bestNextActions || [])[1] || '—'}
3. ${(layer2.bestNextActions || [])[2] || '—'}`;

    document.getElementById('dcc-action-board').textContent =
`TOP PRIORITY NOW
${board.topPriorityNow || '—'}

TOP OFFICE NOW
${board.topOfficeNow || '—'}

TOP ESCALATION
${board.topEscalationNow || '—'}

TEAM BRIEF
${board.teamBriefNow || '—'}

EXECUTIVE NARRATIVE
${board.execNarrativeNow || '—'}`;

    document.getElementById('dcc-ranking').innerHTML = rank.map(r => `
      <div class="dcc-item">
        <div>
          <div><b>#${r.riskRank} ${r.office}</b></div>
          <div class="dcc-sub">${r.summary || ''}</div>
        </div>
        <div class="dcc-rank-${(r.status || 'stable').toLowerCase()}">${r.status || '—'} · ${r.riskScore || 0}</div>
      </div>
    `).join('');

    document.getElementById('dcc-alerts').innerHTML = alerts.length
      ? alerts.map(a => `
        <div class="dcc-alert">
          <b>${a.severity}</b> · ${a.type}<br>
          ${a.message}
        </div>
      `).join('')
      : `<div class="dcc-alert">No active alerts.</div>`;

    document.getElementById('dcc-brief').textContent =
      brief.body || brief.brief || 'No executive brief available.';

    document.getElementById('dcc-offices').innerHTML = this.offices.map(office => `
      <button class="dcc-btn" data-office="${office}" style="${office === (payload.selectedOffice || this.selectedOffice) ? 'border-color:#8fb3ff;background:rgba(143,179,255,.12);' : ''}">
        ${office}
      </button>
    `).join('');

    document.querySelectorAll('[data-office]').forEach(btn => {
      btn.onclick = async () => {
        this.selectedOffice = btn.getAttribute('data-office');
        await this.load();
      };
    });
  },

  bindPrimaryButtons(payload){
    const refresh = document.getElementById('dcc-refresh');
    const cfo = document.getElementById('dcc-cfo');
    const variance = document.getElementById('dcc-variance');
    const mesa = document.getElementById('dcc-mesa');

    if (refresh) refresh.onclick = async () => { await this.load(); };

    if (cfo) cfo.onclick = async () => {
      if (typeof window.quickAsk === 'function') {
        await window.quickAsk(window.HONOR_PACKS?.executive || 'Generate an executive brief for HonorHealth revenue cycle leadership.');
      } else {
        await this.load();
      }
    };

    if (variance) variance.onclick = async () => {
      if (typeof window.quickAsk === 'function') {
        await window.quickAsk(window.HONOR_PACKS?.variance || 'Compare all HonorHealth offices and identify the one needing immediate intervention.');
      }
    };

    if (mesa) mesa.onclick = async () => {
      if (typeof window.quickAsk === 'function') {
        await window.quickAsk('Deep dive on Mesa. What is the root cause and what should the Mesa OM do today?');
      }
    };
  }
};

setTimeout(() => {
  window.DEECC.load().catch(err => console.error('DEECC load failed', err));
}, 500);
</script>
"""

if "window.DEECC" not in text:
    if "</body>" in text:
        text = text.replace("</body>", inject + "\n</body>", 1)
    else:
        text += "\n" + inject

p.write_text(text, encoding="utf-8")
print("Injected Dee Command Center UI")
PY

node -c "$FILE" >/dev/null 2>&1 || true

git add "$FILE"
git commit -m "Upgrade Dee portal to live command center UI" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
