#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/dee_war_room_final
cp -f "$FILE" "backups/dee_war_room_final/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1) Add pulse animation if not present
if "@keyframes wrPulse" not in text:
    text = text.replace(
        "</style>",
        """
.wr-alert.high{
  animation:wrPulse 1.8s infinite;
}
@keyframes wrPulse{
  0%{ box-shadow:0 0 0 rgba(255,111,145,0); }
  50%{ box-shadow:0 0 16px rgba(255,111,145,.35); }
  100%{ box-shadow:0 0 0 rgba(255,111,145,0); }
}
</style>
""",
        1
    )

# 2) Upgrade alert class rendering to support high/medium/low
text = text.replace(
"""document.getElementById('wr-alerts').innerHTML = alerts.length
      ? alerts.map(a => `
        <div class="wr-alert ${String(a.severity || '').toLowerCase() === 'medium' ? 'medium' : ''}">
          <b>${a.severity}</b> · ${a.type}<br>${a.message}
        </div>
      `).join('')
      : '<div class="wr-alert low">No active alerts.</div>';""",
"""document.getElementById('wr-alerts').innerHTML = alerts.length
      ? alerts.map(a => {
          const sev = String(a.severity || '').toLowerCase();
          const cls = sev === 'high' ? 'high' : (sev === 'medium' ? 'medium' : 'low');
          return `
        <div class="wr-alert ${cls}">
          <b>${a.severity}</b> · ${a.type}<br>${a.message}
        </div>
      `;
        }).join('')
      : '<div class="wr-alert low">No active alerts.</div>';"""
)

# 3) Add impact simulation to footer
text = text.replace(
"""    document.getElementById('wr-foot-right').textContent =
      `Top driver: ${sp.topSystemDriver || '—'}`;""",
"""    const projectedRisk = Math.max(0, Number(sp.revenueAtRiskTotal || 0) - Number(layer2.recoverable72h || 0));
    document.getElementById('wr-foot-right').textContent =
      `Top driver: ${sp.topSystemDriver || '—'} · If executed now → projected risk: ${this.money(projectedRisk)}`;"""
)

# 4) Strengthen action board copy with command language
text = text.replace(
"""    document.getElementById('wr-action-board').textContent =
`TSM STRATEGIST
Source: ${sb.source || 'TSM Strategist'}
Office To Escalate: ${sb.officeToEscalate || '—'}
Payer Focus: ${sb.payerFocus || '—'}
Alert Count: ${sb.alertCount || 0}

TOP PRIORITY NOW
${sb.topPriorityNow || '—'}

LIVE SIGNALS
${(sb.liveSignals || []).map((s, i) => `${i+1}. ${s.title} [${String(s.urgency || '').toUpperCase()}] · ${s.source} · ${s.detail}`).join('\\n')}

STRATEGIST NARRATIVE
${sb.strategistNarrative || '—'}

RECOMMENDED ACTIONS
1. ${(sb.actions || [])[0] || '—'}
2. ${(sb.actions || [])[1] || '—'}
3. ${(sb.actions || [])[2] || '—'}`;""",
"""    document.getElementById('wr-action-board').textContent =
`TSM STRATEGIST
Source: ${sb.source || 'TSM Strategist'}
Office To Escalate: ${sb.officeToEscalate || '—'}
Payer Focus: ${sb.payerFocus || '—'}
Alert Count: ${sb.alertCount || 0}

COMMAND DIRECTIVE
${sb.topPriorityNow || '—'}

LIVE SIGNALS
${(sb.liveSignals || []).map((s, i) => `${i+1}. ${s.title} [${String(s.urgency || '').toUpperCase()}] · ${s.source} · ${s.detail}`).join('\\n')}

STRATEGIST NARRATIVE
${sb.strategistNarrative || '—'}

EXECUTE NOW
1. ${(sb.actions || [])[0] || '—'}
2. ${(sb.actions || [])[1] || '—'}
3. ${(sb.actions || [])[2] || '—'}`;"""
)

# 5) Add live directive console trace
text = text.replace(
"""    if(!strategist || !strategist.ok) throw new Error(strategist?.error || 'Strategist bridge failed');

    this.render(payload, strategist);
    this.bindButtons();
    return { payload, strategist };""",
"""    if(!strategist || !strategist.ok) throw new Error(strategist?.error || 'Strategist bridge failed');

    if (strategist.actionBoard?.topPriorityNow) {
      console.log('🔥 LIVE STRATEGIST DIRECTIVE:', strategist.actionBoard.topPriorityNow);
    }

    this.render(payload, strategist);
    this.bindButtons();
    return { payload, strategist };"""
)

# 6) Prevent duplicate button listeners by cloning buttons once per render cycle
text = text.replace(
"""  bindButtons(){
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
  },""",
"""  bindButtons(){
    const bind = (id, fn) => {
      const old = document.getElementById(id);
      if(!old) return;
      const neo = old.cloneNode(true);
      old.parentNode.replaceChild(neo, old);
      neo.onclick = fn;
    };

    bind('wr-refresh', async () => { await this.load(); });
    bind('wr-cfo', async () => {
      if (typeof window.quickAsk === 'function') await window.quickAsk('Generate CFO brief for current selected office and system posture.');
    });
    bind('wr-recovery', async () => {
      if (typeof window.quickAsk === 'function') await window.quickAsk(`Run denial recovery plan for ${this.selectedOffice}`);
    });
    bind('wr-escalate', async () => {
      if (typeof window.quickAsk === 'function') await window.quickAsk(`Draft payer escalation for ${this.selectedOffice}`);
    });
    bind('wr-variance', async () => {
      if (typeof window.quickAsk === 'function') await window.quickAsk('Compare all HonorHealth offices and identify immediate intervention order.');
    });
    bind('wr-strategist', () => {
      window.location.href = '/html/main-strategist/';
    });
  },"""
)

p.write_text(text, encoding="utf-8")
print("Applied final Dee war room polish")
PY

git add "$FILE"
git commit -m "Apply final Dee war room polish" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy

echo "== TEST =="
curl -I https://tsm-shell.fly.dev/html/honor-portal/
curl -X POST https://tsm-shell.fly.dev/api/strategist/hc/dee-action \
  -H "Content-Type: application/json" \
  -d '{"system":"HonorHealth","selectedOffice":"Scottsdale - Shea"}'
