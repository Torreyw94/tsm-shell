#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

DST="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/honor_portal_hard_reset
cp -f "$DST" "backups/honor_portal_hard_reset/index.$STAMP.bak"

cat > "$DST" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>HonorHealth · Dee War Room</title>
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
    .wrap{max-width:1400px;margin:0 auto;padding:22px}
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
    .btn:disabled{opacity:.55;cursor:not-allowed}
    .priority{
      border-left:4px solid var(--amber);background:#0a1822;border-radius:12px;padding:16px;color:#fff
    }
    .priority-title{
      color:var(--amber);font-size:11px;letter-spacing:.14em;text-transform:uppercase;margin-bottom:8px
    }
    .priority-body{font-size:26px;font-weight:800;line-height:1.2}
    .meta{font-size:12px;color:var(--muted);margin-top:8px}
    .grid4{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}
    .card{
      background:var(--panel);border:1px solid rgba(0,255,163,.14);border-radius:12px;padding:14px
    }
    .label{
      font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:#7decc8;margin-bottom:8px
    }
    .value{font-size:30px;font-weight:800;line-height:1.1;color:#fff}
    .stack{display:grid;gap:10px}
    .alert{
      background:#09141d;border:1px solid rgba(255,255,255,.08);border-left:4px solid var(--green);
      border-radius:10px;padding:12px
    }
    .alert.high{border-left-color:var(--red)}
    .alert.medium{border-left-color:#ffd166}
    .alert-head{font-size:11px;text-transform:uppercase;letter-spacing:.12em;color:#8fd7bd;margin-bottom:6px}
    .alert-msg{font-size:14px;color:#fff}
    .offices{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}
    .office{
      background:#09141d;border:1px solid rgba(255,255,255,.08);border-left:4px solid var(--green);
      border-radius:10px;padding:12px;cursor:pointer
    }
    .office.high{border-left-color:var(--red)}
    .office.medium{border-left-color:#ffd166}
    .office.stable{border-left-color:var(--green)}
    .office-name{font-size:13px;font-weight:800;color:#fff;margin-bottom:6px}
    .office-sub{font-size:12px;color:var(--muted);line-height:1.45}
    .narrative{
      white-space:pre-wrap;background:#09141d;border:1px solid rgba(255,255,255,.08);
      border-radius:12px;padding:14px;color:#d9fff2;font-size:14px;line-height:1.55
    }
    .loading{color:var(--muted)}
    @media (max-width:1100px){.grid4,.actions,.offices{grid-template-columns:1fr 1fr}}
    @media (max-width:700px){.grid4,.actions,.offices{grid-template-columns:1fr}}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="topbar">
      <div>
        <div class="brand">HonorHealth · Dee War Room</div>
        <div class="persona">Dee Montee · Revenue Cycle Manager · HonorHealth</div>
      </div>
      <div class="status" id="war-status">LIVE</div>
    </div>

    <div class="section">
      <div class="section-title">Immediate Actions</div>
      <div class="actions">
        <button class="btn" type="button" data-action="Generate a full team briefing for HonorHealth revenue cycle">Generate Team Briefing</button>
        <button class="btn" type="button" data-action="Run denial recovery strategy for Scottsdale - Shea">Run Denial Recovery</button>
        <button class="btn" type="button" data-action="Escalate payer auth blockers for Scottsdale - Shea">Escalate Payer</button>
        <button class="btn" type="button" data-action="Compare Scottsdale - Shea vs best-performing office">Compare Office</button>
        <button class="btn" type="button" data-action="Return the top priority action for HonorHealth revenue cycle right now">Top Priority</button>
        <button class="btn" type="button" data-action="Generate executive brief for Dee Montee on current revenue posture">Executive Brief</button>
      </div>
    </div>

    <div id="war-room" class="section">
      <div class="loading">Loading war room...</div>
    </div>
  </div>

  <script>
    window.DEE_SELECTED_OFFICE = 'Scottsdale - Shea';
    window.DEE_LAST_ACTION = 'initial load';
    window.DEE_LOADING = false;

    function esc(v){
      return String(v == null ? '' : v)
        .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
    }
    function money(n){ return '$' + Number(n || 0).toLocaleString(); }

    function renderWarRoom(data){
      const target = document.getElementById('war-room');
      const ab = data.actionBoard || {};
      const l = data.layer2 || {};
      const alerts = data.alerts || [];
      const posture = data.posture || data.systemPosture || {};
      const ranking = posture.officeRanking || data.officeRanking || [];
      const actions = (ab.actions && ab.actions.length) ? ab.actions : [
        'Run denial recovery strategy for ' + window.DEE_SELECTED_OFFICE,
        'Escalate payer auth blockers for ' + window.DEE_SELECTED_OFFICE,
        'Generate executive brief for ' + window.DEE_SELECTED_OFFICE
      ];

      target.innerHTML = `
        <div class="priority">
          <div class="priority-title">Top Priority</div>
          <div class="priority-body">${esc(ab.topPriorityNow || ('Intervene in ' + window.DEE_SELECTED_OFFICE))}</div>
          <div class="meta">
            Selected Office: ${esc(window.DEE_SELECTED_OFFICE)} ·
            Last Action: ${esc(window.DEE_LAST_ACTION)} ·
            Payer Focus: ${esc(ab.payerFocus || 'Prior Authorization')}
          </div>
        </div>

        <div class="grid4" style="margin-top:14px">
          <div class="card"><div class="label">Revenue At Risk</div><div class="value">${money(l.revenueAtRisk)}</div></div>
          <div class="card"><div class="label">Recoverable 72h</div><div class="value">${money(l.recoverable72h)}</div></div>
          <div class="card"><div class="label">14d Acceleration</div><div class="value">${money(l.cashAcceleration14d)}</div></div>
          <div class="card"><div class="label">Highest Yield Lane</div><div class="value" style="font-size:22px">${esc(l.highestYieldLane || 'Insurance')}</div></div>
        </div>

        <div class="section" style="margin-top:14px;padding:14px">
          <div class="section-title">Recommended Actions</div>
          <div class="actions">
            ${actions.map(a => `<button class="btn" type="button" data-action="${esc(a)}">${esc(a)}</button>`).join('')}
          </div>
        </div>

        <div class="section" style="margin-top:14px;padding:14px">
          <div class="section-title">Alert Stack</div>
          <div class="stack">
            ${alerts.length ? alerts.map(a => `
              <div class="alert ${esc(String(a.severity || '').toLowerCase())}">
                <div class="alert-head">${esc(a.type)} · ${esc(a.severity)}</div>
                <div class="alert-msg">${esc(a.message)}</div>
              </div>
            `).join('') : '<div class="alert"><div class="alert-msg">No active alerts</div></div>'}
          </div>
        </div>

        <div class="section" style="margin-top:14px;padding:14px">
          <div class="section-title">Office Heatmap</div>
          <div class="offices">
            ${ranking.length ? ranking.map(o => `
              <div class="office ${esc(String(o.status || 'stable').toLowerCase())}" data-office="${esc(o.office)}">
                <div class="office-name">${esc(o.office)}</div>
                <div class="office-sub">Rank #${esc(o.riskRank || '')} · Score ${esc(o.riskScore || '')}<br>${esc(o.summary || '')}</div>
              </div>
            `).join('') : `<div class="office medium" data-office="${esc(window.DEE_SELECTED_OFFICE)}"><div class="office-name">${esc(window.DEE_SELECTED_OFFICE)}</div><div class="office-sub">Selected command office</div></div>`}
          </div>
        </div>

        <div class="section" style="margin-top:14px;padding:14px">
          <div class="section-title">Strategist Narrative</div>
          <div class="narrative">${esc(ab.strategistNarrative || '')}</div>
        </div>
      `;
    }

    async function runDeeAction(prompt){
      if (window.DEE_LOADING) return;
      window.DEE_LOADING = true;
      window.DEE_LAST_ACTION = prompt || 'initial load';
      document.getElementById('war-status').textContent = 'RUNNING';

      try {
        const res = await fetch('/api/strategist/hc/dee-action', {
          method:'POST',
          headers:{'Content-Type':'application/json'},
          body: JSON.stringify({
            system:'HonorHealth',
            selectedOffice: window.DEE_SELECTED_OFFICE,
            prompt: prompt || ''
          })
        });
        const data = await res.json();
        renderWarRoom(data);
      } catch (e) {
        document.getElementById('war-room').innerHTML = '<div class="alert high"><div class="alert-msg">War room request failed: ' + esc(e.message) + '</div></div>';
      } finally {
        window.DEE_LOADING = false;
        document.getElementById('war-status').textContent = 'LIVE';
      }
    }

    document.addEventListener('click', function(e){
      const actionBtn = e.target.closest('[data-action]');
      if (actionBtn) {
        e.preventDefault();
        runDeeAction(actionBtn.getAttribute('data-action'));
        return;
      }
      const officeTile = e.target.closest('[data-office]');
      if (officeTile) {
        e.preventDefault();
        window.DEE_SELECTED_OFFICE = officeTile.getAttribute('data-office');
        runDeeAction('refresh command view for ' + window.DEE_SELECTED_OFFICE);
      }
    });

    window.addEventListener('load', function(){
      runDeeAction('initial load');
    });
  </script>
</body>
</html>
HTML

git add "$DST"
git commit -m "Hard reset honor portal to single Dee war room" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
