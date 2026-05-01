#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

DST="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/honor_portal_modes
cp -f "$DST" "backups/honor_portal_modes/index.$STAMP.bak"

cat > "$DST" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>HonorHealth · Dee Command Center</title>
<style>
  :root{
    --bg:#050b14;
    --panel:#081722;
    --panel2:#0a1822;
    --line:rgba(0,255,163,.18);
    --text:#d9fff2;
    --muted:#9fdcc9;
    --cyan:#56d7ff;
    --green:#00ffa3;
    --amber:#ffcc66;
    --red:#ff6b6b;
    --purple:#ad7bff;
  }
  *{box-sizing:border-box}
  html,body{margin:0;padding:0;background:var(--bg);color:var(--text);font-family:Inter,Arial,sans-serif}
  body{min-height:100vh;overflow-x:hidden}
  .wrap{max-width:1380px;margin:0 auto;padding:22px}
  .topbar{
    display:flex;align-items:center;justify-content:space-between;gap:16px;
    padding:14px 18px;border:1px solid var(--line);border-radius:14px;
    background:linear-gradient(180deg,#06111d,#071420);margin-bottom:16px
  }
  .brand{font-size:14px;letter-spacing:.18em;text-transform:uppercase;color:var(--cyan)}
  .persona{font-size:13px;color:var(--muted)}
  .status{font-size:12px;color:var(--green);text-transform:uppercase;letter-spacing:.14em}
  .section{
    border:1px solid var(--line);
    border-radius:16px;
    background:linear-gradient(180deg,#06111d,#071420);
    padding:18px;
    margin-bottom:16px;
  }
  .section-title{
    font-size:12px;letter-spacing:.16em;text-transform:uppercase;color:var(--cyan);margin-bottom:12px
  }
  .actions{
    display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:10px
  }
  .btn{
    appearance:none;border:1px solid rgba(0,255,163,.18);background:#0a1822;color:#d9fff2;
    border-radius:10px;padding:12px 14px;text-align:left;cursor:pointer;font-size:13px;font-weight:700;
  }
  .btn:hover{background:#0d1d28}
  .btn.active{border-color:var(--amber);box-shadow:0 0 0 1px rgba(255,204,102,.25) inset}
  .btn:disabled{opacity:.55;cursor:not-allowed}
  .priority{
    border-left:4px solid var(--amber);background:#0a1822;border-radius:12px;padding:16px;color:#fff
  }
  .priority-title{
    color:var(--amber);font-size:11px;letter-spacing:.14em;text-transform:uppercase;margin-bottom:8px
  }
  .priority-body{font-size:24px;font-weight:800;line-height:1.2}
  .meta{font-size:12px;color:var(--muted);margin-top:8px}
  .mode-pill{
    display:inline-flex;align-items:center;gap:6px;padding:6px 10px;border-radius:999px;
    border:1px solid rgba(173,123,255,.28);background:rgba(173,123,255,.08);
    color:#d8c7ff;font-size:11px;letter-spacing:.12em;text-transform:uppercase;margin-top:10px
  }
  .grid2{display:grid;grid-template-columns:1fr 1fr;gap:14px}
  .grid3{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
  .grid4{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}
  .card{
    background:var(--panel);border:1px solid rgba(0,255,163,.14);border-radius:12px;padding:14px
  }
  .label{
    font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:#7decc8;margin-bottom:8px
  }
  .value{font-size:28px;font-weight:800;line-height:1.1;color:#fff}
  .stack{display:grid;gap:10px}
  .alert{
    background:#09141d;border:1px solid rgba(255,255,255,.08);border-left:4px solid var(--green);
    border-radius:10px;padding:12px
  }
  .alert.high{border-left-color:var(--red)}
  .alert.medium{border-left-color:#ffd166}
  .alert.low{border-left-color:var(--green)}
  .alert-head{font-size:11px;text-transform:uppercase;letter-spacing:.12em;color:#8fd7bd;margin-bottom:6px}
  .alert-msg{font-size:14px;color:#fff}
  .narrative{
    white-space:pre-wrap;background:#09141d;border:1px solid rgba(255,255,255,.08);
    border-radius:12px;padding:14px;color:#d9fff2;font-size:14px;line-height:1.55
  }
  .loading{color:var(--muted)}
  .list{display:grid;gap:8px}
  .item{
    background:#09141d;border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:12px
  }
  .item-head{font-size:11px;text-transform:uppercase;letter-spacing:.12em;color:#8fd7bd;margin-bottom:6px}
  .item-body{font-size:14px;color:#fff;line-height:1.45}
  @media (max-width:1100px){.actions,.grid2,.grid3,.grid4{grid-template-columns:1fr 1fr}}
  @media (max-width:700px){.actions,.grid2,.grid3,.grid4{grid-template-columns:1fr}}
</style>
</head>
<body>
  <div class="wrap">
    <div class="topbar">
      <div>
        <div class="brand">HonorHealth · Dee Command Center</div>
        <div class="persona">Dee Montee · Revenue Cycle Manager · Scottsdale - Shea</div>
      </div>
      <div class="status" id="war-status">LIVE</div>
    </div>

    <div class="section">
      <div class="section-title">Immediate Actions</div>
      <div class="actions">
        <button class="btn" type="button" data-mode="recovery">Run Recovery</button>
        <button class="btn" type="button" data-mode="payer">Escalate Payer</button>
        <button class="btn" type="button" data-mode="brief">Executive Brief</button>
      </div>
    </div>

    <div id="view" class="section">
      <div class="loading">Loading command center...</div>
    </div>
  </div>

<script>
window.DEE_SELECTED_OFFICE = 'Scottsdale - Shea';
window.DEE_LAST_MODE = 'recovery';
window.DEE_LOADING = false;

function esc(v){
  return String(v == null ? '' : v)
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;');
}
function money(n){ return '$' + Number(n || 0).toLocaleString(); }

function modePrompt(mode){
  if(mode === 'payer') return 'Escalate payer auth blockers for Scottsdale - Shea';
  if(mode === 'brief') return 'Generate executive brief for Dee Montee on current revenue posture';
  return 'Run denial recovery strategy for Scottsdale - Shea';
}
function modeLabel(mode){
  if(mode === 'payer') return 'Payer Intervention';
  if(mode === 'brief') return 'Executive Summary';
  return 'Revenue Recovery';
}

async function fetchAction(mode){
  const res = await fetch('/api/strategist/hc/dee-action', {
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body: JSON.stringify({
      system:'HonorHealth',
      selectedOffice: window.DEE_SELECTED_OFFICE,
      prompt: modePrompt(mode)
    })
  });
  return await res.json();
}

function renderRecovery(data){
  const ab = data.actionBoard || {};
  const l = data.layer2 || {};
  const alerts = (data.alerts || []).filter(a => String(a.type || '').toLowerCase().includes('denial') || String(a.type || '').toLowerCase().includes('queue'));
  return `
    <div class="priority">
      <div class="priority-title">Top Recovery Priority</div>
      <div class="priority-body">${esc(ab.topPriorityNow || 'Run denial recovery')}</div>
      <div class="meta">Office: ${esc(window.DEE_SELECTED_OFFICE)} · Mode: Recovery</div>
      <div class="mode-pill">${esc(modeLabel('recovery'))}</div>
    </div>

    <div class="grid4" style="margin-top:14px">
      <div class="card"><div class="label">Recoverable 72h</div><div class="value">${money(l.recoverable72h)}</div></div>
      <div class="card"><div class="label">Revenue At Risk</div><div class="value">${money(l.revenueAtRisk)}</div></div>
      <div class="card"><div class="label">14d Acceleration</div><div class="value">${money(l.cashAcceleration14d)}</div></div>
      <div class="card"><div class="label">Highest Yield Lane</div><div class="value" style="font-size:22px">${esc(l.highestYieldLane || 'Insurance')}</div></div>
    </div>

    <div class="grid2" style="margin-top:14px">
      <div class="card">
        <div class="label">Recovery Actions</div>
        <div class="list">
          ${(l.bestNextActions || []).map(x => `<div class="item"><div class="item-body">${esc(x)}</div></div>`).join('') || '<div class="item"><div class="item-body">No recovery actions returned.</div></div>'}
        </div>
      </div>
      <div class="card">
        <div class="label">Owner Lanes</div>
        <div class="list">
          ${(l.ownerLanes || []).map(x => `<div class="item"><div class="item-body">${esc(x)}</div></div>`).join('') || '<div class="item"><div class="item-body">No owner lanes returned.</div></div>'}
        </div>
      </div>
    </div>

    <div class="section" style="margin-top:14px;padding:14px">
      <div class="section-title">Recovery Alerts</div>
      <div class="stack">
        ${alerts.length ? alerts.map(a => `
          <div class="alert ${esc(String(a.severity || '').toLowerCase())}">
            <div class="alert-head">${esc(a.type)} · ${esc(a.severity)}</div>
            <div class="alert-msg">${esc(a.message)}</div>
          </div>
        `).join('') : '<div class="alert"><div class="alert-msg">No recovery alerts.</div></div>'}
      </div>
    </div>

    <div class="section" style="margin-top:14px;padding:14px">
      <div class="section-title">Recovery Narrative</div>
      <div class="narrative">${esc(ab.strategistNarrative || '')}</div>
    </div>
  `;
}

function renderPayer(data){
  const ab = data.actionBoard || {};
  const posture = data.posture || {};
  const alerts = (data.alerts || []).filter(a => String(a.type || '').toLowerCase().includes('auth'));
  const signals = ab.liveSignals || [];
  return `
    <div class="priority">
      <div class="priority-title">Payer Intervention Focus</div>
      <div class="priority-body">${esc(ab.payerFocus || 'Prior Authorization')}</div>
      <div class="meta">Office: ${esc(window.DEE_SELECTED_OFFICE)} · Mode: Payer</div>
      <div class="mode-pill">${esc(modeLabel('payer'))}</div>
    </div>

    <div class="grid3" style="margin-top:14px">
      <div class="card"><div class="label">Top Payer Focus</div><div class="value" style="font-size:22px">${esc(ab.payerFocus || 'Prior Authorization')}</div></div>
      <div class="card"><div class="label">Top Office</div><div class="value" style="font-size:22px">${esc(ab.officeToEscalate || window.DEE_SELECTED_OFFICE)}</div></div>
      <div class="card"><div class="label">Overall Risk</div><div class="value" style="font-size:22px">${esc((ab.posture || posture.systemPosture || {}).overallRisk || 'high')}</div></div>
    </div>

    <div class="grid2" style="margin-top:14px">
      <div class="card">
        <div class="label">Payer Signals</div>
        <div class="list">
          ${signals.length ? signals.map(s => `
            <div class="item">
              <div class="item-head">${esc(s.title)} · ${esc(s.urgency)}</div>
              <div class="item-body">${esc(s.detail)}</div>
            </div>
          `).join('') : '<div class="item"><div class="item-body">No payer signals returned.</div></div>'}
        </div>
      </div>
      <div class="card">
        <div class="label">Auth Delay Alerts</div>
        <div class="stack">
          ${alerts.length ? alerts.map(a => `
            <div class="alert ${esc(String(a.severity || '').toLowerCase())}">
              <div class="alert-head">${esc(a.type)} · ${esc(a.severity)}</div>
              <div class="alert-msg">${esc(a.message)}</div>
            </div>
          `).join('') : '<div class="alert"><div class="alert-msg">No auth delay alerts.</div></div>'}
        </div>
      </div>
    </div>

    <div class="section" style="margin-top:14px;padding:14px">
      <div class="section-title">Payer Narrative</div>
      <div class="narrative">${esc(ab.strategistNarrative || '')}</div>
    </div>
  `;
}

function renderBrief(data){
  const ab = data.actionBoard || {};
  const posture = data.posture || {};
  const sp = posture.systemPosture || {};
  const ranking = posture.officeRanking || [];
  return `
    <div class="priority">
      <div class="priority-title">Executive Brief</div>
      <div class="priority-body">${esc(ab.topPriorityNow || sp.topSystemDriver || 'HonorHealth risk summary')}</div>
      <div class="meta">Office: ${esc(window.DEE_SELECTED_OFFICE)} · Mode: Brief</div>
      <div class="mode-pill">${esc(modeLabel('brief'))}</div>
    </div>

    <div class="grid4" style="margin-top:14px">
      <div class="card"><div class="label">Overall Risk</div><div class="value" style="font-size:22px">${esc(sp.overallRisk || 'high')}</div></div>
      <div class="card"><div class="label">Top Risk Office</div><div class="value" style="font-size:22px">${esc(sp.topRiskOffice || window.DEE_SELECTED_OFFICE)}</div></div>
      <div class="card"><div class="label">Top System Lane</div><div class="value" style="font-size:22px">${esc(sp.topSystemLane || 'Operations')}</div></div>
      <div class="card"><div class="label">72h Recoverable</div><div class="value">${money(sp.recoverable72hTotal)}</div></div>
    </div>

    <div class="grid2" style="margin-top:14px">
      <div class="card">
        <div class="label">Executive Narrative</div>
        <div class="narrative">${esc(ab.strategistNarrative || ab.execNarrativeNow || 'No executive narrative returned.')}</div>
      </div>
      <div class="card">
        <div class="label">Office Ranking</div>
        <div class="list">
          ${ranking.length ? ranking.map(o => `
            <div class="item">
              <div class="item-head">#${esc(o.riskRank)} · ${esc(o.office)} · ${esc(o.status)}</div>
              <div class="item-body">${esc(o.summary || '')}</div>
            </div>
          `).join('') : '<div class="item"><div class="item-body">No office ranking returned.</div></div>'}
        </div>
      </div>
    </div>
  `;
}

async function runMode(mode){
  if(window.DEE_LOADING) return;
  window.DEE_LOADING = true;
  window.DEE_LAST_MODE = mode;
  document.getElementById('war-status').textContent = 'RUNNING';
  document.querySelectorAll('[data-mode]').forEach(btn => btn.classList.remove('active'));
  const active = document.querySelector('[data-mode="' + mode + '"]');
  if(active) active.classList.add('active');

  try{
    const data = await fetchAction(mode);
    const target = document.getElementById('view');
    if(mode === 'payer'){
      target.innerHTML = renderPayer(data);
    } else if(mode === 'brief'){
      target.innerHTML = renderBrief(data);
    } else {
      target.innerHTML = renderRecovery(data);
    }
  } catch(e){
    document.getElementById('view').innerHTML = '<div class="alert high"><div class="alert-msg">Request failed: ' + esc(e.message) + '</div></div>';
  } finally {
    window.DEE_LOADING = false;
    document.getElementById('war-status').textContent = 'LIVE';
  }
}

document.addEventListener('click', function(e){
  const btn = e.target.closest('[data-mode]');
  if(!btn) return;
  e.preventDefault();
  runMode(btn.getAttribute('data-mode'));
});

window.addEventListener('load', function(){
  runMode('recovery');
});
  </script>
</body>
</html>
HTML

git add "$DST"
git commit -m "Rebuild Dee page with real differentiated modes" || true
git push origin main || true
fly deploy
