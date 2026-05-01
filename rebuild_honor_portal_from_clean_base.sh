#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

SRC="html/honor-portal/nu-dee-portal.html"
DST="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p backups/honor_portal_rebuild
cp -f "$DST" "backups/honor_portal_rebuild/index.$STAMP.bak"

# 1) Replace the broken index with the clean Dee base
cp -f "$SRC" "$DST"

python3 <<'PY'
from pathlib import Path

p = Path("html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 2) Make scrolling sane
text = text.replace("height:100vh;overflow:hidden;display:flex;flex-direction:column",
                    "min-height:100vh;overflow-x:hidden;overflow-y:auto;display:flex;flex-direction:column")

# 3) Add one clean Dee output surface if missing
if 'id="dee-live-output"' not in text:
    marker = '<div id="dee-brain-actions"'
    idx = text.find(marker)
    if idx != -1:
        end = text.find('</div>', idx)
        # find the matching end of the actions block more safely by taking the next double newline section
        insert_at = text.find('</div>', end + 1)
        if insert_at != -1:
            insert_at += len('</div>')
            text = text[:insert_at] + '''

<div id="dee-live-output" style="margin:18px 0;padding:18px;border:1px solid rgba(0,255,163,.18);border-radius:14px;background:#06121c;color:#d9fff2;font-family:Inter,Arial,sans-serif;">
  <div style="font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:#7decc8;margin-bottom:10px;">Dee Live Command Output</div>
  <div id="dee-live-inner" style="color:#9fdcc9">Loading...</div>
</div>
''' + text[insert_at:]

# 4) Append one clean controller only once
if 'window.__DEE_CLEAN_CONTROLLER__' not in text:
    text = text.replace('</body>', r'''
<style id="dee-clean-controller-style">
#dee-live-inner{display:grid;gap:14px}
.dee-priority{border-left:4px solid #ffcc66;background:#0a1822;border-radius:12px;padding:16px;color:#fff;font-size:20px;font-weight:800}
.dee-meta{font-size:12px;color:#9fdcc9;margin-top:8px}
.dee-card-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}
.dee-card{background:#081722;border:1px solid rgba(0,255,163,.14);border-radius:12px;padding:14px;color:#fff}
.dee-card small{display:block;font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:#7decc8;margin-bottom:8px}
.dee-alert{background:#09141d;border:1px solid rgba(255,255,255,.08);border-left:4px solid #00ffa3;border-radius:10px;padding:12px;color:#fff}
.dee-alert.high{border-left-color:#ff6b6b}
.dee-alert.medium{border-left-color:#ffd166}
.dee-actions{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}
.dee-btn{appearance:none;border:1px solid rgba(0,255,163,.18);background:#0a1822;color:#d9fff2;border-radius:10px;padding:12px 14px;text-align:left;cursor:pointer;font-size:13px;font-weight:700}
.dee-btn:disabled{opacity:.55;cursor:not-allowed}
.dee-narrative{white-space:pre-wrap;background:#09141d;border:1px solid rgba(255,255,255,.08);border-radius:12px;padding:14px;color:#d9fff2;font-size:14px;line-height:1.55}
@media (max-width:1100px){.dee-card-grid,.dee-actions{grid-template-columns:1fr 1fr}}
@media (max-width:700px){.dee-card-grid,.dee-actions{grid-template-columns:1fr}}
</style>

<script>
window.__DEE_CLEAN_CONTROLLER__ = true;
window.DEE_SELECTED_OFFICE = 'Scottsdale - Shea';
window.DEE_LOADING = false;
window.DEE_LAST_ACTION = 'initial load';

function deeEsc(v){
  return String(v == null ? '' : v)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
function deeMoney(n){
  return '$' + Number(n || 0).toLocaleString();
}
async function quickAsk(promptText){
  if (window.DEE_LOADING) return;
  window.DEE_LOADING = true;
  window.DEE_LAST_ACTION = promptText || 'initial load';

  const out = document.getElementById('dee-live-inner');
  if (!out) return;

  out.innerHTML = '<div class="dee-narrative">Running: ' + deeEsc(window.DEE_LAST_ACTION) + '</div>';

  try{
    const res = await fetch('/api/strategist/hc/dee-action', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        system:'HonorHealth',
        selectedOffice: window.DEE_SELECTED_OFFICE,
        prompt: promptText || ''
      })
    });

    const data = await res.json();
    const ab = data.actionBoard || {};
    const l = data.layer2 || {};
    const alerts = data.alerts || [];
    const actions = (ab.actions && ab.actions.length) ? ab.actions : [
      'Run denial recovery plan for ' + window.DEE_SELECTED_OFFICE,
      'Escalate payer auth blockers for ' + window.DEE_SELECTED_OFFICE,
      'Compare ' + window.DEE_SELECTED_OFFICE + ' vs best-performing office'
    ];

    out.innerHTML = `
      <div class="dee-priority">
        ${deeEsc(ab.topPriorityNow || ('Intervene in ' + window.DEE_SELECTED_OFFICE))}
        <div class="dee-meta">Last action: ${deeEsc(window.DEE_LAST_ACTION)} · Payer Focus: ${deeEsc(ab.payerFocus || 'Prior Authorization')}</div>
      </div>

      <div class="dee-card-grid">
        <div class="dee-card"><small>Revenue At Risk</small>${deeMoney(l.revenueAtRisk)}</div>
        <div class="dee-card"><small>Recoverable 72h</small>${deeMoney(l.recoverable72h)}</div>
        <div class="dee-card"><small>14d Acceleration</small>${deeMoney(l.cashAcceleration14d)}</div>
        <div class="dee-card"><small>Highest Yield Lane</small>${deeEsc(l.highestYieldLane || 'Insurance')}</div>
      </div>

      ${alerts.map(a => `<div class="dee-alert ${deeEsc(String(a.severity || '').toLowerCase())}">${deeEsc(a.type)}: ${deeEsc(a.message)}</div>`).join('')}

      <div class="dee-actions">
        ${actions.map(a => `<button class="dee-btn" type="button" data-dee-action="${deeEsc(a)}">${deeEsc(a)}</button>`).join('')}
      </div>

      <div class="dee-narrative">${deeEsc(ab.strategistNarrative || '')}</div>
    `;

    out.querySelectorAll('[data-dee-action]').forEach(btn => {
      btn.addEventListener('click', function(){
        quickAsk(this.getAttribute('data-dee-action'));
      });
    });

    return data;
  } catch(e){
    out.innerHTML = '<div class="dee-alert high">Dee action failed: ' + deeEsc(e.message) + '</div>';
  } finally {
    window.DEE_LOADING = false;
  }
}

window.addEventListener('load', function(){
  const loadingNodes = Array.from(document.querySelectorAll('body *')).filter(el => (el.textContent || '').trim() === 'Loading...');
  loadingNodes.forEach(el => { if (el.id !== 'dee-live-inner') el.remove(); });
  quickAsk('initial load');
});
</script>
</body>''')

p.write_text(text, encoding="utf-8")
print("Rebuilt honor portal clean from nu-dee-portal.html")
PY

git add "$DST"
git commit -m "Rebuild honor portal clean from Dee base" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
