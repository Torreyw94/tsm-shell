#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.btnfix.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# Add a little visual feedback CSS if not already present
if ".dee-btn.loading" not in text:
    text = text.replace(
        "</style>",
        """
.dee-btn.loading{
  opacity:.65;
  pointer-events:none;
}
.dee-last-action{
  font-size:12px;
  color:#9fdcc9;
  margin-top:8px;
}
</style>
""",
        1
    )

# Replace the current force override quickAsk block with a version that tracks/loading/rebinds.
pattern = r"window\.quickAsk\s*=\s*async function\(promptText\)\s*\{[\s\S]*?\n\};"
replacement = r"""
window.DEE_SELECTED_OFFICE = window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea';
window.DEE_LAST_ACTION = window.DEE_LAST_ACTION || '';
window.DEE_LOADING = false;

window.quickAsk = async function(promptText){
  if (window.DEE_LOADING) return;
  window.DEE_LOADING = true;
  window.DEE_LAST_ACTION = promptText || '';

  const target = document.getElementById('dee-live-output');
  if (target) {
    Array.prototype.forEach.call(target.querySelectorAll('.dee-btn'), function(btn){
      btn.classList.add('loading');
      btn.disabled = true;
    });
  }

  try {
    const res = await fetch('/api/strategist/hc/dee-action', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        system:'HonorHealth',
        selectedOffice: window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea',
        prompt: promptText || ''
      })
    });

    const data = await res.json();
    const t = document.getElementById('dee-live-output');
    if (!t) {
      window.DEE_LOADING = false;
      return data;
    }

    const ab = data.actionBoard || {};
    const l = data.layer2 || {};
    const alerts = data.alerts || [];
    const actions = (ab.actions && ab.actions.length) ? ab.actions : [
      'Run denial recovery plan for ' + (window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea'),
      'Escalate payer auth blockers for ' + (window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea'),
      'Compare ' + (window.DEE_SELECTED_OFFICE || 'Scottsdale - Shea') + ' vs best-performing office'
    ];

    const esc = function(v){
      return String(v == null ? '' : v)
        .replace(/&/g,'&amp;')
        .replace(/</g,'&lt;')
        .replace(/>/g,'&gt;')
        .replace(/"/g,'&quot;');
    };

    const money = function(n){
      return '$' + Number(n || 0).toLocaleString();
    };

    t.innerHTML = `
      <div class="dee-priority">
        ${esc(ab.topPriorityNow || 'Intervene in Scottsdale - Shea')}
        <div class="dee-last-action">Last action: ${esc(window.DEE_LAST_ACTION || 'initial load')}</div>
      </div>

      <div class="dee-card-grid">
        <div class="dee-card">${money(l.revenueAtRisk)}<br>Risk</div>
        <div class="dee-card">${money(l.recoverable72h)}<br>Recoverable</div>
        <div class="dee-card">${money(l.cashAcceleration14d)}<br>14d</div>
        <div class="dee-card">${esc(l.highestYieldLane || 'Insurance')}<br>Lane</div>
      </div>

      ${alerts.map(function(a){
        const sev = String(a.severity || '').toLowerCase();
        return '<div class="dee-alert ' + esc(sev) + '">' + esc(a.type) + ': ' + esc(a.message) + '</div>';
      }).join('')}

      <div class="dee-actions">
        ${actions.map(function(a){
          return '<button class="dee-btn" data-action="' + esc(a) + '">' + esc(a) + '</button>';
        }).join('')}
      </div>
    `;

    Array.prototype.forEach.call(t.querySelectorAll('[data-action]'), function(btn){
      btn.onclick = function(){
        return window.quickAsk(btn.getAttribute('data-action'));
      };
    });

    return data;
  } catch(e){
    console.error('quickAsk failed', e);
    return { ok:false, error:e.message };
  } finally {
    window.DEE_LOADING = false;
    const t = document.getElementById('dee-live-output');
    if (t) {
      Array.prototype.forEach.call(t.querySelectorAll('.dee-btn'), function(btn){
        btn.classList.remove('loading');
        btn.disabled = false;
      });
    }
  }
};"""
text, count = re.subn(pattern, replacement, text, count=1)
if count == 0:
    raise SystemExit("Could not find quickAsk function to replace")

p.write_text(text, encoding="utf-8")
print("Fixed Dee button feedback and rebind behavior")
PY

git add "$FILE"
git commit -m "Fix Dee button feedback and repeat-click behavior" || true
git push origin main || true
fly deploy
