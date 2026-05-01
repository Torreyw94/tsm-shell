#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
STAMP=$(date +%s)

mkdir -p backups/dee_final
cp "$FILE" "backups/dee_final/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

inject = r"""
<script>
window.DEENEURAL = {
  async post(url, body){
    const r = await fetch(url,{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify(body)
    });
    const t = await r.text();
    if(t.startsWith('<!DOCTYPE')||t.startsWith('<html')){
      throw new Error('HTML fallback: '+url);
    }
    return JSON.parse(t);
  },

  money(v){return '$'+Number(v||0).toLocaleString();},

  async load(){
    const data = await this.post('/api/honor/dee/dashboard',{
      system:'HonorHealth'
    });

    const office = data.selectedOfficeData || {};
    const layer2 = office.layer2 || {};
    const state = office.state || {};
    const posture = data.systemPosture || {};

    this.renderKPIs(layer2);
    this.renderState(state);
    this.renderBoard(posture);
  },

  renderKPIs(l){
    const el = document.createElement('div');
    el.style.cssText='margin:12px 0;padding:10px;border:1px solid rgba(0,255,100,.15);';

    el.innerHTML = `
      <b>LIVE KPI</b><br>
      Risk: ${this.money(l.revenueAtRisk)}<br>
      72h: ${this.money(l.recoverable72h)}<br>
      14d: ${this.money(l.cashAcceleration14d)}<br>
      Lane: ${l.highestYieldLane || '—'}
    `;

    document.body.appendChild(el);
  },

  renderState(s){
    const ops = s.operations||{};
    const bill = s.billing||{};
    const ins = s.insurance||{};

    const el = document.createElement('div');
    el.style.cssText='margin:12px 0;padding:10px;border:1px solid rgba(0,170,255,.15);white-space:pre-wrap;';

    el.innerHTML = `
OPERATIONS
Queue: ${ops.queueDepth||0}
Backlog: ${ops.intakeBacklog||0}
Staff: ${ops.staffingCoverage||0}%

BILLING
Denial: ${bill.denialRate||0}%
Lag: ${bill.claimLagDays||0}d
AR>30: ${this.money(bill.arOver30)}

INSURANCE
Auth: ${ins.authBacklog||0}
Delay: ${ins.authDelayHours||0}h
    `;

    document.body.appendChild(el);
  },

  renderBoard(p){
    const board = p.deeActionBoard||{};
    const rank = p.officeRanking||[];

    const el = document.createElement('div');
    el.style.cssText='margin:12px 0;padding:12px;border:1px solid rgba(255,255,255,.1);';

    el.innerHTML = `
      <b>DEE COMMAND</b><br><br>
      Priority: ${board.topPriorityNow||'—'}<br>
      Office: ${board.topOfficeNow||'—'}<br>
      Escalation: ${board.topEscalationNow||'—'}<br><br>

      <b>OFFICE RANKING</b><br>
      ${rank.map(r=>`#${r.riskRank} ${r.office} (${r.riskScore})`).join('<br>')}
    `;

    document.body.appendChild(el);
  }
};

setTimeout(()=>window.DEENEURAL.load().catch(console.error),500);
</script>
"""

if inject not in text:
    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("Injected Dee Neural Render")
PY

git add "$FILE"
git commit -m "Dee portal final render wiring" || true

git pull --rebase origin main || true
git push origin main || true

fly deploy
