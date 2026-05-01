#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.forceclean.$(date +%s)"

cat >> "$FILE" <<'JS'

<!-- ===== FORCE CLEAN DEE RENDER ===== -->
<style>
#dee-live-output{
  margin-top:20px;
  padding:20px;
  border:1px solid rgba(0,255,163,.18);
  background:#06121c;
  color:#d9fff2;
  font-family:Inter,Arial,sans-serif;
  border-radius:14px;
}
.dee-priority{
  border-left:4px solid #ffcc66;
  background:#0a1822;
  padding:16px;
  margin-bottom:16px;
  font-size:20px;
  font-weight:800;
}
.dee-card-grid{
  display:grid;
  grid-template-columns:repeat(4,1fr);
  gap:12px;
}
.dee-card{
  background:#081722;
  border:1px solid rgba(0,255,163,.14);
  padding:14px;
  border-radius:10px;
}
.dee-actions{
  display:grid;
  grid-template-columns:repeat(3,1fr);
  gap:10px;
  margin-top:16px;
}
.dee-btn{
  background:#0a1822;
  border:1px solid rgba(0,255,163,.18);
  color:#d9fff2;
  padding:10px;
  cursor:pointer;
}
.dee-alert{
  margin-top:10px;
  padding:10px;
  border-left:4px solid #ff6b6b;
  background:#09141d;
}
</style>

<script>
window.quickAsk = async function(promptText){
  const res = await fetch('/api/strategist/hc/dee-action', {
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body: JSON.stringify({
      system:'HonorHealth',
      selectedOffice:'Scottsdale - Shea',
      prompt: promptText || ''
    })
  });

  const data = await res.json();
  const t = document.getElementById('dee-live-output');

  const ab = data.actionBoard || {};
  const l = data.layer2 || {};
  const alerts = data.alerts || [];

  t.innerHTML = `
    <div class="dee-priority">
      ${ab.topPriorityNow || 'Intervene in Scottsdale - Shea'}
    </div>

    <div class="dee-card-grid">
      <div class="dee-card">$${(l.revenueAtRisk||0).toLocaleString()}<br>Risk</div>
      <div class="dee-card">$${(l.recoverable72h||0).toLocaleString()}<br>Recoverable</div>
      <div class="dee-card">$${(l.cashAcceleration14d||0).toLocaleString()}<br>14d</div>
      <div class="dee-card">${l.highestYieldLane || 'Insurance'}<br>Lane</div>
    </div>

    ${alerts.map(a=>`
      <div class="dee-alert">
        ${a.type}: ${a.message}
      </div>
    `).join('')}

    <div class="dee-actions">
      ${(ab.actions||[]).map(a=>`
        <button class="dee-btn" onclick="quickAsk('${a}')">${a}</button>
      `).join('')}
    </div>
  `;
};
</script>

JS

git add "$FILE"
git commit -m "Force clean Dee render override" || true
git push origin main || true
fly deploy
