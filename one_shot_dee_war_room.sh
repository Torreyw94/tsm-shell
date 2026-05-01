#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/dee_war_room
cp -f "$FILE" "backups/dee_war_room/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# Replace current Dee command center block if present
pattern = r"<style>\s*#dee-command-center\{[\s\S]*?</style>\s*<script>\s*window\.DEECC\s*=\s*\{[\s\S]*?setTimeout\(\s*\(\)\s*=>\s*\{\s*window\.DEECC\.load\(\)[\s\S]*?</script>"
text = re.sub(pattern, "", text, flags=re.S)

inject = r"""
<style>
:root{
  --wr-bg:#050b14;
  --wr-panel:#081321;
  --wr-panel-2:#0b1728;
  --wr-line:rgba(94,166,255,.18);
  --wr-text:#dbe8ff;
  --wr-muted:#8fa6c7;
  --wr-cyan:#56d7ff;
  --wr-green:#4cffb2;
  --wr-amber:#ffc857;
  --wr-red:#ff6f91;
  --wr-violet:#ad7bff;
}

#dee-command-center{
  margin:16px 0 24px;
  background:
    linear-gradient(rgba(86,215,255,.04), rgba(86,215,255,.01)),
    repeating-linear-gradient(0deg, rgba(86,215,255,.035) 0 1px, transparent 1px 32px),
    repeating-linear-gradient(90deg, rgba(86,215,255,.03) 0 1px, transparent 1px 32px),
    var(--wr-bg);
  border:1px solid var(--wr-line);
  border-radius:18px;
  color:var(--wr-text);
  padding:14px;
  box-shadow:0 0 0 1px rgba(86,215,255,.04) inset, 0 20px 50px rgba(0,0,0,.35);
  max-height:calc(100vh - 150px);
  overflow:auto;
}
#dee-command-center *{box-sizing:border-box}
#dee-command-center .wr-header{
  display:grid;
  grid-template-columns:1.2fr .85fr;
  gap:12px;
  margin-bottom:12px;
}
#dee-command-center .wr-head-card{
  background:linear-gradient(180deg, rgba(255,255,255,.03), rgba(255,255,255,.015));
  border:1px solid var(--wr-line);
  border-radius:14px;
  padding:12px;
  min-height:88px;
}
#dee-command-center .wr-title{
  font-size:13px;
  letter-spacing:.22em;
  text-transform:uppercase;
  color:var(--wr-cyan);
  margin-bottom:8px;
}
#dee-command-center .wr-sub{
  color:var(--wr-muted);
  font-size:12px;
  line-height:1.5;
}
#dee-command-center .wr-banner{
  display:flex;
  justify-content:space-between;
  gap:10px;
  align-items:center;
  margin-top:8px;
  font-size:12px;
  color:var(--wr-muted);
}
#dee-command-center .wr-kpis{
  display:grid;
  grid-template-columns:repeat(6,minmax(0,1fr));
  gap:10px;
  margin-bottom:12px;
}
#dee-command-center .wr-kpi{
  border:1px solid var(--wr-line);
  background:linear-gradient(180deg, rgba(255,255,255,.025), rgba(255,255,255,.01));
  border-radius:14px;
  padding:10px;
  min-height:90px;
  position:relative;
  overflow:hidden;
}
#dee-command-center .wr-kpi::after{
  content:"";
  position:absolute;
  inset:auto -20% -40% auto;
  width:140px;
  height:140px;
  background:radial-gradient(circle, rgba(86,215,255,.10), transparent 65%);
  pointer-events:none;
}
#dee-command-center .wr-kpi-lab{
  font-size:10px;
  letter-spacing:.18em;
  text-transform:uppercase;
  color:var(--wr-muted);
  margin-bottom:8px;
}
#dee-command-center .wr-kpi-val{
  font-size:18px;
  font-weight:800;
  color:#fff;
  line-height:1.1;
}
#dee-command-center .wr-grid{
  display:grid;
  grid-template-columns:330px 1fr 360px;
  gap:12px;
}
#dee-command-center .wr-col{
  display:grid;
  gap:12px;
  align-content:start;
}
#dee-command-center .wr-panel{
  background:linear-gradient(180deg, rgba(255,255,255,.025), rgba(255,255,255,.01));
  border:1px solid var(--wr-line);
  border-radius:14px;
  padding:12px;
  min-height:220px;
  max-height:420px;
  overflow:auto;
}
#dee-command-center .wr-panel.tall{
  min-height:420px;
}
#dee-command-center .wr-panel.short{
  min-height:160px;
  max-height:220px;
}
#dee-command-center .wr-panel-head{
  display:flex;
  justify-content:space-between;
  align-items:center;
  gap:10px;
  margin-bottom:10px;
  padding-bottom:8px;
  border-bottom:1px solid rgba(86,215,255,.10);
}
#dee-command-center .wr-panel-title{
  font-size:11px;
  letter-spacing:.18em;
  text-transform:uppercase;
  color:var(--wr-cyan);
}
#dee-command-center .wr-chip{
  border:1px solid rgba(86,215,255,.18);
  border-radius:999px;
  padding:4px 8px;
  font-size:10px;
  color:var(--wr-muted);
}
#dee-command-center .wr-pre{
  white-space:pre-wrap;
  line-height:1.65;
  font-size:13px;
}
#dee-command-center .wr-list{
  display:grid;
  gap:8px;
}
#dee-command-center .wr-item{
  display:flex;
  justify-content:space-between;
  gap:10px;
  padding:10px;
  border:1px solid rgba(86,215,255,.12);
  border-radius:12px;
  background:rgba(255,255,255,.02);
  cursor:pointer;
}
#dee-command-center .wr-item:hover{
  background:rgba(86,215,255,.07);
  border-color:rgba(86,215,255,.28);
}
#dee-command-center .wr-item b{
  color:#fff;
}
#dee-command-center .wr-item-sub{
  color:var(--wr-muted);
  font-size:12px;
  line-height:1.45;
}
#dee-command-center .wr-stat-high{color:var(--wr-amber)}
#dee-command-center .wr-stat-critical{color:var(--wr-red)}
#dee-command-center .wr-stat-medium{color:var(--wr-cyan)}
#dee-command-center .wr-stat-stable{color:var(--wr-green)}
#dee-command-center .wr-actions{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:8px;
  margin-top:12px;
}
#dee-command-center .wr-btn{
  border:1px solid rgba(86,215,255,.20);
  background:rgba(86,215,255,.07);
  color:var(--wr-text);
  border-radius:12px;
  padding:10px 12px;
  font-size:12px;
  cursor:pointer;
  text-align:left;
}
#dee-command-center .wr-btn:hover{
  background:rgba(86,215,255,.12);
}
#dee-command-center .wr-alert{
  padding:10px;
  border-left:3px solid var(--wr-red);
  background:rgba(255,255,255,.025);
  border-radius:10px;
  font-size:12px;
  line-height:1.5;
}
#dee-command-center .wr-alert.medium{border-left-color:var(--wr-amber)}
#dee-command-center .wr-alert.low{border-left-color:var(--wr-cyan)}
#dee-command-center .wr-heatmap{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:8px;
}
#dee-command-center .wr-heat{
  border:1px solid rgba(86,215,255,.10);
  border-radius:12px;
  padding:10px;
  min-height:92px;
}
#dee-command-center .wr-heat.high{background:rgba(255,200,87,.10)}
#dee-command-center .wr-heat.critical{background:rgba(255,111,145,.12)}
#dee-command-center .wr-heat.medium{background:rgba(86,215,255,.08)}
#dee-command-center .wr-heat.stable{background:rgba(76,255,178,.08)}
#dee-command-center .wr-foot{
  margin-top:12px;
  display:flex;
  justify-content:space-between;
  gap:10px;
  color:var(--wr-muted);
  font-size:11px;
}
@media (max-width:1380px){
  #dee-command-center{max-height:none}
  #dee-command-center .wr-header{grid-template-columns:1fr}
  #dee-command-center .wr-kpis{grid-template-columns:repeat(3,minmax(0,1fr))}
  #dee-command-center .wr-grid{grid-template-columns:1fr}
  #dee-command-center .wr-panel{max-height:none}
}
</style>

<script>
window.DEECC = {
  system: 'HonorHealth',
  selectedOffice: 'Scottsdale - Shea',
  offices: ['Scottsdale - Shea','Mesa','Tempe','North Mountain'],
  timer: null,

  money(v){ return '$' + Number(v || 0).toLocaleString(); },

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

  ensureShell(){
    let shell = document.getElementById('dee-command-center');
    if(shell) return shell;

    shell = document.createElement('section');
    shell.id = 'dee-command-center';
    shell.innerHTML = `
      <div class="wr-header">
        <div class="wr-head-card">
          <div class="wr-title">HonorHealth Revenue Command War Room</div>
          <div class="wr-sub" id="wr-subtitle">Dee Montee · Revenue Cycle Manager · Cross-office operational intelligence</div>
          <div class="wr-banner">
            <span id="wr-sync">Syncing...</span>
            <span>Mesh: HC Nodes → HC Strategist → TSM Strategist → Dee Command</span>
          </div>
        </div>
        <div class="wr-head-card">
          <div class="wr-title">Command Status</div>
          <div class="wr-sub" id="wr-status-copy">Loading strategist bridge and office posture...</div>
          <div class="wr-banner">
            <span id="wr-top-office">Top office: —</span>
            <span id="wr-alert-count">Alerts: 0</span>
          </div>
        </div>
      </div>

      <div class="wr-kpis" id="wr-kpis"></div>

      <div class="wr-grid">
        <div class="wr-col">
          <div class="wr-panel tall">
            <div class="wr-panel-head">
              <div class="wr-panel-title">Selected Office Live State</div>
              <div class="wr-chip" id="wr-office-chip">Scottsdale - Shea</div>
            </div>
            <div class="wr-pre" id="wr-office-state">Loading office state...</div>
          </div>

          <div class="wr-panel short">
            <div class="wr-panel-head">
              <div class="wr-panel-title">Alerts</div>
              <div class="wr-chip">Live</div>
            </div>
            <div class="wr-list" id="wr-alerts"></div>
          </div>
        </div>

        <div class="wr-col">
          <div class="wr-panel tall">
            <div class="wr-panel-head">
              <div class="wr-panel-title">Dee Action Board</div>
              <div class="wr-chip">Command</div>
            </div>
            <div class="wr-pre" id="wr-action-board">Loading action board...</div>
            <div class="wr-actions">
              <button class="wr-btn" id="wr-refresh">↻ Refresh Command View</button>
              <button class="wr-btn" id="wr-cfo">✦ Generate CFO Brief</button>
              <button class="wr-btn" id="wr-recovery">⚡ Run Recovery Plan</button>
              <button class="wr-btn" id="wr-escalate">⇡ Escalate Payer Blockers</button>
              <button class="wr-btn" id="wr-variance">◈ Compare All Offices</button>
              <button class="wr-btn" id="wr-strategist">◎ Open TSM Strategist</button>
            </div>
          </div>

          <div class="wr-panel short">
            <div class="wr-panel-head">
              <div class="wr-panel-title">Executive Brief</div>
              <div class="wr-chip">Leadership</div>
            </div>
            <div class="wr-pre" id="wr-brief">Loading brief...</div>
          </div>
        </div>

        <div class="wr-col">
          <div class="wr-panel tall">
            <div class="wr-panel-head">
              <div class="wr-panel-title">System Ranking</div>
              <div class="wr-chip" id="wr-risk-chip">Risk: —</div>
            </div>
            <div class="wr-list" id="wr-ranking"></div>
          </div>

          <div class="wr-panel short">
            <div class="wr-panel-head">
              <div class="wr-panel-title">Pressure Heatmap</div>
              <div class="wr-chip">War Room</div>
            </div>
            <div class="wr-heatmap" id="wr-heatmap"></div>
          </div>
        </div>
      </div>

      <div class="wr-foot">
        <span id="wr-foot-left">TSM Command active</span>
        <span id="wr-foot-right">Awaiting next refresh...</span>
      </div>
    `;

    const anchor =
      document.querySelector('#honor-neural-panel') ||
      document.querySelector('[data-email="brief"]')?.parentElement?.parentElement ||
      document.body;

    anchor.parentElement.insertBefore(shell, anchor.nextSibling);
    return shell;
  },

  render(payload, strategist){
    this.ensureShell();

    const selected = payload.selectedOfficeData || {};
    const state = selected.state || {};
    const layer2 = selected.layer2 || {};
    const brief = selected.brief || {};
    const posture = payload.systemPosture || {};
    const sp = posture.systemPosture || {};
    const rank = posture.officeRanking || [];
    const alerts = payload.alerts || [];
    const sb = strategist?.actionBoard || {};

    document.getElementById('wr-subtitle').textContent =
      `${payload.persona?.name || 'Dee Montee'} · ${payload.persona?.role || 'Revenue Cycle Manager'} · Selected office: ${payload.selectedOffice || this.selectedOffice}`;

    document.getElementById('wr-sync').textContent =
      'Last sync: ' + new Date(payload.generatedAt || Date.now()).toLocaleString();

    document.getElementById('wr-status-copy').textContent =
      sb.strategistNarrative || 'Strategist bridge active and monitoring office posture.';

    document.getElementById('wr-top-office').textContent =
      `Top office: ${sp.topRiskOffice || this.selectedOffice}`;

    document.getElementById('wr-alert-count').textContent =
      `Alerts: ${alerts.length || 0}`;

    document.getElementById('wr-risk-chip').textContent =
      `Risk: ${sp.overallRisk || '—'}`;

    document.getElementById('wr-office-chip').textContent =
      payload.selectedOffice || this.selectedOffice;

    document.getElementById('wr-kpis').innerHTML = `
      <div class="wr-kpi"><div class="wr-kpi-lab">Selected Office Risk</div><div class="wr-kpi-val">${this.money(layer2.revenueAtRisk)}</div></div>
      <div class="wr-kpi"><div class="wr-kpi-lab">72H Recoverable</div><div class="wr-kpi-val">${this.money(layer2.recoverable72h)}</div></div>
      <div class="wr-kpi"><div class="wr-kpi-lab">14D Acceleration</div><div class="wr-kpi-val">${this.money(layer2.cashAcceleration14d)}</div></div>
      <div class="wr-kpi"><div class="wr-kpi-lab">Yield Lane</div><div class="wr-kpi-val">${layer2.highestYieldLane || '—'}</div></div>
      <div class="wr-kpi"><div class="wr-kpi-lab">Top Risk Office</div><div class="wr-kpi-val">${sp.topRiskOffice || '—'}</div></div>
      <div class="wr-kpi"><div class="wr-kpi-lab">System Risk Total</div><div class="wr-kpi-val">${this.money(sp.revenueAtRiskTotal)}</div></div>
    `;

    const ops = state.operations || {};
    const billing = state.billing || {};
    const insurance = state.insurance || {};
    document.getElementById('wr-office-state').textContent =
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

ROOT CAUSE
- ${(layer2.rootCause || []).join('\n- ')}

BEST NEXT ACTIONS
1. ${(layer2.bestNextActions || [])[0] || '—'}
2. ${(layer2.bestNextActions || [])[1] || '—'}
3. ${(layer2.bestNextActions || [])[2] || '—'}`;

    document.getElementById('wr-action-board').textContent =
`TSM STRATEGIST
Source: ${sb.source || 'TSM Strategist'}
Office To Escalate: ${sb.officeToEscalate || '—'}
Payer Focus: ${sb.payerFocus || '—'}
Alert Count: ${sb.alertCount || 0}

TOP PRIORITY NOW
${sb.topPriorityNow || '—'}

LIVE SIGNALS
${(sb.liveSignals || []).map((s, i) => `${i+1}. ${s.title} [${String(s.urgency || '').toUpperCase()}] · ${s.source} · ${s.detail}`).join('\n')}

STRATEGIST NARRATIVE
${sb.strategistNarrative || '—'}

RECOMMENDED ACTIONS
1. ${(sb.actions || [])[0] || '—'}
2. ${(sb.actions || [])[1] || '—'}
3. ${(sb.actions || [])[2] || '—'}`;

    document.getElementById('wr-brief').textContent =
      brief.body || brief.brief || 'No executive brief available.';

    document.getElementById('wr-ranking').innerHTML = rank.map(r => `
      <div class="wr-item" data-rank-office="${r.office}">
        <div>
          <div><b>#${r.riskRank} ${r.office}</b></div>
          <div class="wr-item-sub">${r.summary || ''}</div>
        </div>
        <div class="wr-stat-${String(r.status || 'stable').toLowerCase()}">${r.status || '—'} · ${r.riskScore || 0}</div>
      </div>
    `).join('');

    document.getElementById('wr-alerts').innerHTML = alerts.length
      ? alerts.map(a => `
        <div class="wr-alert ${String(a.severity || '').toLowerCase() === 'medium' ? 'medium' : ''}">
          <b>${a.severity}</b> · ${a.type}<br>${a.message}
        </div>
      `).join('')
      : '<div class="wr-alert low">No active alerts.</div>';

    document.getElementById('wr-heatmap').innerHTML = rank.map(r => `
      <div class="wr-heat ${String(r.status || 'stable').toLowerCase()}">
        <b>${r.office}</b><br>
        ${r.primaryDriver || '—'} · ${r.riskScore || 0}
      </div>
    `).join('');

    document.querySelectorAll('[data-rank-office]').forEach(row => {
      row.onclick = async () => {
        this.selectedOffice = row.getAttribute('data-rank-office');
        await this.load();
      };
    });

    document.getElementById('wr-foot-left').textContent =
      `Selected office: ${payload.selectedOffice || this.selectedOffice} · Best office: ${sp.bestPerformingOffice || '—'}`;

    document.getElementById('wr-foot-right').textContent =
      `Top driver: ${sp.topSystemDriver || '—'}`;
  },

  bindButtons(){
    const q = (id) => document.getElementById(id);

    if (q('wr-refresh')) q('wr-refresh').onclick = async () => { await this.load(); };
    if (q('wr-cfo')) q('wr-cfo').onclick = async () => {
      if (typeof window.quickAsk === 'function') await window.quickAsk('Generate CFO brief for current selected office and system posture.');
    };
    if (q('wr-recovery')) q('wr-recovery').onclick = async () => {
      if (typeof window.quickAsk === 'function') await window.quickAsk(`Run denial recovery plan for ${this.selectedOffice}`);
    };
    if (q('wr-escalate')) q('wr-escalate').onclick = async () => {
      if (typeof window.quickAsk === 'function') await window.quickAsk(`Draft payer escalation for ${this.selectedOffice}`);
    };
    if (q('wr-variance')) q('wr-variance').onclick = async () => {
      if (typeof window.quickAsk === 'function') await window.quickAsk('Compare all HonorHealth offices and identify immediate intervention order.');
    };
    if (q('wr-strategist')) q('wr-strategist').onclick = () => {
      window.location.href = '/html/main-strategist/';
    };
  },

  async load(){
    const payload = await this.post('/api/honor/dee/dashboard', {
      system: this.system,
      selectedOffice: this.selectedOffice,
      offices: this.offices
    });

    const strategist = await this.post('/api/strategist/hc/dee-action', {
      system: this.system,
      selectedOffice: this.selectedOffice,
      offices: this.offices
    });

    if(!payload || !payload.ok) throw new Error(payload?.error || 'Dashboard load failed');
    if(!strategist || !strategist.ok) throw new Error(strategist?.error || 'Strategist bridge failed');

    this.render(payload, strategist);
    this.bindButtons();
    return { payload, strategist };
  },

  startAutoRefresh(){
    if (this.timer) clearInterval(this.timer);
    this.timer = setInterval(() => {
      this.load().catch(err => console.error('War room refresh failed', err));
    }, 15000);
  }
};

setTimeout(() => {
  window.DEECC.load().then(() => window.DEECC.startAutoRefresh()).catch(err => console.error('War room load failed', err));
}, 500);
</script>
"""

if "HonorHealth Revenue Command War Room" not in text:
    if "</body>" in text:
        text = text.replace("</body>", inject + "\n</body>", 1)
    else:
        text += "\n" + inject

p.write_text(text, encoding="utf-8")
print("Applied Dee war room UI")
PY

git add "$FILE"
git commit -m "Upgrade Dee portal to war room UI" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
