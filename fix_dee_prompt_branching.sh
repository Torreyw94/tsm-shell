#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/tsm-shell

python3 <<'PY'
from pathlib import Path

p = Path("server.js")
text = p.read_text(encoding="utf-8")

OLD = """    const {
      system = 'HonorHealth',
      selectedOffice = 'Scottsdale - Shea',
      offices = ['Scottsdale - Shea', 'Mesa', 'Tempe', 'North Mountain']
    } = req.body || {};"""

NEW = """    const {
      system = 'HonorHealth',
      selectedOffice = 'Scottsdale - Shea',
      offices = ['Scottsdale - Shea', 'Mesa', 'Tempe', 'North Mountain'],
      prompt = ''
    } = req.body || {};"""

assert OLD in text, "Could not find target block"
text = text.replace(OLD, NEW, 1)

OLD2 = """    return res.json({
      ok: true,
      source: 'TSM Strategist',
      generatedAt: new Date().toISOString(),
      selectedOffice,
      layer2,
      posture,
      alerts,
      actionBoard
    });"""

NEW2 = """    // Prompt-based action branching
    const promptLower = (prompt || '').toLowerCase();
    let actionView = 'default';
    if (promptLower.includes('denial recovery')) actionView = 'denial';
    else if (promptLower.includes('auth blocker') || promptLower.includes('payer')) actionView = 'auth';
    else if (promptLower.includes('compare') || promptLower.includes('best-performing')) actionView = 'compare';

    let actionDetail = null;
    if (actionView === 'denial') {
      actionDetail = {
        view: 'denial',
        title: 'Denial Recovery Plan',
        steps: [
          `1. Pull all denied claims for ${selectedOffice} from last 30 days`,
          `2. Sort by denial reason — current top: ${selectedBilling.denialRate || 0}% rate`,
          `3. Resubmit clean claims within 72h — ${layer2.recoverable72h ? '$'+Number(layer2.recoverable72h).toLocaleString()+' recoverable' : 'calculate recoverable'}`,
          `4. Escalate payer-specific denials to billing lead`,
          `5. Flag claim lag (${selectedBilling.claimLagDays || 0}d) for process review`,
        ],
        metric: { label: 'Denial Rate', value: selectedBilling.denialRate + '%', target: '<5%' }
      };
    } else if (actionView === 'auth') {
      actionDetail = {
        view: 'auth',
        title: 'Payer Auth Escalation',
        steps: [
          `1. Pull all pending auth requests for ${selectedOffice} older than 24h`,
          `2. Auth backlog: ${selectedInsurance.authBacklog || 0} cases · delay: ${selectedInsurance.authDelayHours || 0}h`,
          `3. Call top 3 payers directly — prioritize Medicare/Prior Auth cases`,
          `4. Submit peer-to-peer review requests for denials over $5,000`,
          `5. Escalate unresolved auths >72h to medical director`,
        ],
        metric: { label: 'Auth Delay', value: selectedInsurance.authDelayHours + 'h', target: '<24h' }
      };
    } else if (actionView === 'compare') {
      const best = officePayloads.find(o => o.office === posture?.systemPosture?.bestPerformingOffice) || officePayloads[1];
      actionDetail = {
        view: 'compare',
        title: `${selectedOffice} vs ${best?.office || 'Best Office'}`,
        comparison: [
          { label: 'Denial Rate', selected: selectedBilling.denialRate + '%', best: (best?.layer2?.denialRate || 0) + '%' },
          { label: 'Auth Delay', selected: selectedInsurance.authDelayHours + 'h', best: (best?.layer2?.authDelayHours || 0) + 'h' },
          { label: 'Queue Depth', selected: selectedOps.queueDepth, best: best?.layer2?.queueDepth || 0 },
          { label: 'Revenue at Risk', selected: '$'+Number(layer2.revenueAtRisk||0).toLocaleString(), best: '$'+Number(best?.layer2?.revenueAtRisk||0).toLocaleString() },
          { label: 'Recoverable 72h', selected: '$'+Number(layer2.recoverable72h||0).toLocaleString(), best: '$'+Number(best?.layer2?.recoverable72h||0).toLocaleString() },
        ]
      };
    }

    return res.json({
      ok: true,
      source: 'TSM Strategist',
      generatedAt: new Date().toISOString(),
      selectedOffice,
      prompt,
      actionView,
      actionDetail,
      layer2,
      posture,
      alerts,
      actionBoard
    });"""

assert OLD2 in text, "Could not find return block"
text = text.replace(OLD2, NEW2, 1)

p.write_text(text, encoding="utf-8")
print("Done - prompt branching added to dee-action endpoint")
PY

node -c server.js && echo "Syntax OK" || echo "SYNTAX ERROR"
git add server.js
git commit -m "Add prompt-based action branching to dee-action endpoint"
git push origin main
fly deploy
