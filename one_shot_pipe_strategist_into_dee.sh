#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/pipe_strategist_into_dee
cp -f server.js "backups/pipe_strategist_into_dee/server.$STAMP.bak"
cp -f html/honor-portal/index.html "backups/pipe_strategist_into_dee/honor-portal.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

server = Path("/workspaces/tsm-shell/server.js")
honor = Path("/workspaces/tsm-shell/html/honor-portal/index.html")

s = server.read_text(encoding="utf-8", errors="ignore")
h = honor.read_text(encoding="utf-8", errors="ignore")

route = r"""
app.post('/api/strategist/hc/dee-action', (req, res) => {
  try {
    const {
      system = 'HonorHealth',
      selectedOffice = 'Scottsdale - Shea',
      offices = ['Scottsdale - Shea', 'Mesa', 'Tempe', 'North Mountain']
    } = req.body || {};

    const state = readJson(HC_NODE_STATE_FILE, {});
    const selectedState = filterHCState(state, system, selectedOffice);
    const layer2 = buildLayer2Summary(selectedState, system, selectedOffice);

    const officePayloads = offices.map(office => {
      const officeState = filterHCState(state, system, office);
      const officeLayer2 = buildLayer2Summary(officeState, system, office);
      return { office, state: officeState, layer2: officeLayer2 };
    });

    const posture = buildStrategistSystemPosture(system, officePayloads);

    const alerts = [];
    Object.entries(state || {}).forEach(([nodeKey, n]) => {
      if (!n || typeof n !== 'object') return;
      if (system && (n.system || '') !== system) return;

      if (n.denialRate != null && Number(n.denialRate) > 10) {
        alerts.push({
          type: 'DENIAL_SPIKE',
          severity: 'HIGH',
          nodeKey,
          location: n.location || 'Unknown',
          officeName: n.officeName || '',
          message: `${n.location || 'Unknown'}: denial rate ${n.denialRate}%`
        });
      }

      if (n.authDelayHours != null && Number(n.authDelayHours) > 48) {
        alerts.push({
          type: 'AUTH_DELAY',
          severity: 'HIGH',
          nodeKey,
          location: n.location || 'Unknown',
          officeName: n.officeName || '',
          message: `${n.location || 'Unknown'}: auth delay ${n.authDelayHours}h`
        });
      }

      if (n.queueDepth != null && Number(n.queueDepth) > 25) {
        alerts.push({
          type: 'QUEUE_PRESSURE',
          severity: 'MEDIUM',
          nodeKey,
          location: n.location || 'Unknown',
          officeName: n.officeName || '',
          message: `${n.location || 'Unknown'}: queue depth ${n.queueDepth}`
        });
      }
    });

    const top = posture?.officeRanking?.[0] || {};
    const selectedOps = selectedState.operations || {};
    const selectedBilling = selectedState.billing || {};
    const selectedInsurance = selectedState.insurance || {};

    const liveSignals = [
      {
        title: 'Top Priority',
        urgency: top.status || 'high',
        source: top.office || selectedOffice,
        detail: top.summary || `Intervene in ${selectedOffice}`
      },
      {
        title: 'Payer Friction',
        urgency: Number(selectedInsurance.authDelayHours || 0) > 48 ? 'urgent' : 'med',
        source: selectedOffice,
        detail: `Auth backlog ${selectedInsurance.authBacklog || 0} · delay ${selectedInsurance.authDelayHours || 0}h`
      },
      {
        title: 'Denial Pressure',
        urgency: Number(selectedBilling.denialRate || 0) > 10 ? 'urgent' : 'med',
        source: selectedOffice,
        detail: `Denial ${selectedBilling.denialRate || 0}% · lag ${selectedBilling.claimLagDays || 0}d`
      },
      {
        title: 'Throughput',
        urgency: Number(selectedOps.queueDepth || 0) > 25 ? 'high' : 'med',
        source: selectedOffice,
        detail: `Queue ${selectedOps.queueDepth || 0} · backlog ${selectedOps.intakeBacklog || 0} · staffing ${selectedOps.staffingCoverage || 0}%`
      }
    ];

    const actionBoard = {
      source: 'TSM Strategist',
      selectedOffice,
      posture: posture.systemPosture || {},
      topPriorityNow: top.summary || `Intervene in ${selectedOffice}`,
      officeToEscalate: top.office || selectedOffice,
      payerFocus: Number(selectedInsurance.authDelayHours || 0) > 48 ? 'Prior Authorization' : 'Medicare',
      liveSignals,
      actions: [
        `Run denial recovery plan for ${selectedOffice}`,
        `Escalate payer auth blockers for ${selectedOffice}`,
        `Compare ${selectedOffice} vs best-performing office`
      ],
      strategistNarrative:
        `${system} risk is concentrated in ${top.office || selectedOffice}. ` +
        `Highest-yield lane is ${layer2.highestYieldLane || 'Billing'}. ` +
        `Immediate focus: ${layer2.bestNextActions?.[0] || 'Clear highest-value backlog first'}`,
      alertCount: alerts.length
    };

    return res.json({
      ok: true,
      source: 'TSM Strategist',
      generatedAt: new Date().toISOString(),
      selectedOffice,
      layer2,
      posture,
      alerts,
      actionBoard
    });
  } catch (e) {
    return res.status(500).json({ ok:false, error:e.message });
  }
});
"""

if "/api/strategist/hc/dee-action" not in s:
    m = re.search(r"\napp\.listen\(PORT,", s)
    if not m:
        raise SystemExit("Could not find insertion point before app.listen")
    idx = m.start()
    s = s[:idx] + "\n" + route + "\n" + s[idx:]

patch = r"""
<script>
(function(){
  function applyStrategistToDee(){
    if(!window.DEECC || window.DEECC.__tsmStrategistPatched) return;
    window.DEECC.__tsmStrategistPatched = true;

    const origLoad = window.DEECC.load.bind(window.DEECC);

    window.DEECC.renderStrategistActionBoard = function(pkt){
      if(!pkt || !pkt.ok) return;
      const board = pkt.actionBoard || {};
      const el = document.getElementById('dcc-action-board');
      if(!el) return;

      const stratBlock = `
TSM STRATEGIST
Source: ${board.source || 'TSM Strategist'}
Office To Escalate: ${board.officeToEscalate || '—'}
Payer Focus: ${board.payerFocus || '—'}
Alert Count: ${board.alertCount || 0}

LIVE SIGNALS
${(board.liveSignals || []).map((s, i) => `${i+1}. ${s.title} [${String(s.urgency || '').toUpperCase()}] · ${s.source} · ${s.detail}`).join('\n')}

STRATEGIST NARRATIVE
${board.strategistNarrative || '—'}

RECOMMENDED ACTIONS
1. ${(board.actions || [])[0] || '—'}
2. ${(board.actions || [])[1] || '—'}
3. ${(board.actions || [])[2] || '—'}

----------------------------------------

`;

      if(!el.dataset.baseBoard){
        el.dataset.baseBoard = el.textContent || '';
      }
      el.textContent = stratBlock + el.dataset.baseBoard;
    };

    window.DEECC.load = async function(){
      const payload = await origLoad();
      try {
        const strategist = await this.post('/api/strategist/hc/dee-action', {
          system: this.system,
          selectedOffice: this.selectedOffice,
          offices: this.offices
        });
        this.renderStrategistActionBoard(strategist);
      } catch (e) {
        console.warn('TSM Strategist bridge failed', e);
      }
      return payload;
    };

    let btn = document.getElementById('dcc-open-strategist');
    if(!btn){
      const actions = document.querySelector('#dee-command-center .dcc-actions');
      if(actions){
        btn = document.createElement('button');
        btn.id = 'dcc-open-strategist';
        btn.className = 'dcc-btn';
        btn.textContent = 'Open TSM Strategist';
        btn.onclick = () => { window.location.href = '/html/main-strategist/'; };
        actions.appendChild(btn);
      }
    }
  }

  setTimeout(applyStrategistToDee, 900);
})();
</script>
"""

if "renderStrategistActionBoard" not in h:
    if "</body>" in h:
        h = h.replace("</body>", patch + "\n</body>", 1)
    else:
        h += "\n" + patch

server.write_text(s, encoding="utf-8")
honor.write_text(h, encoding="utf-8")
print("Patched strategist->Dee bridge")
PY

echo "== VERIFY =="
grep -n "/api/strategist/hc/dee-action" server.js || true
grep -n "renderStrategistActionBoard\|dcc-open-strategist" html/honor-portal/index.html || true

echo "== SYNTAX CHECK =="
node -c server.js

echo "== COMMIT =="
git add server.js html/honor-portal/index.html
git commit -m "Pipe TSM Strategist output into Dee action board" || true

echo "== PUSH =="
git pull --rebase origin main || true
git push origin main || true

echo "== DEPLOY =="
fly deploy

echo "== TEST =="
curl -X POST https://tsm-shell.fly.dev/api/strategist/hc/dee-action \
  -H "Content-Type: application/json" \
  -d '{"system":"HonorHealth","selectedOffice":"Scottsdale - Shea"}'
