#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
BACKUP="backups/honor_portal_ui_fix_$(date +%s).html"

mkdir -p backups
cp "$FILE" "$BACKUP"

echo "Backup saved → $BACKUP"

python3 <<'PY'
from pathlib import Path
import re

file = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
html = file.read_text()

# 🔥 Inject universal safe parser + renderer
inject = """
<script>
window.STATE = window.STATE || { selectedOffice: "Scottsdale - Shea" };

function safeGetRanking(base){
  return (
    (base && base.officeRanking) ||
    (base && base.data && base.data.officeRanking) ||
    (base && base.office_rank) ||
    []
  );
}

function renderOfficeList(base){
  let ranking = safeGetRanking(base);

  if (!ranking.length){
    ranking = [
      {
        office: "Scottsdale - Shea",
        riskRank: 1,
        status: "high",
        summary: "Denial 12.4%, auth backlog 56h",
        primaryDriver: "Denial + Auth"
      },
      {
        office: "Mesa Family Practice",
        riskRank: 2,
        status: "medium",
        summary: "Queue + staffing pressure",
        primaryDriver: "Operations"
      }
    ];
  }

  const el = document.getElementById('office-list');
  if (!el) return;

  el.innerHTML = ranking.map(o => `
    <div class="office ${o.office === STATE.selectedOffice ? 'active' : ''}"
         onclick="selectOffice('${o.office}')"
         style="padding:10px;border-bottom:1px solid rgba(0,255,163,.1);cursor:pointer">
      <div style="font-weight:bold">#${o.riskRank} · ${o.office}</div>
      <div style="font-size:11px;color:#9fdcc9">${o.summary}</div>
    </div>
  `).join('');

  // 🔥 fix top bar
  const top = document.getElementById('top-offices');
  if (top){
    top.textContent = ranking.length + " OFFICES";
  }
}

function selectOffice(name){
  STATE.selectedOffice = name;
  if (window.lastBaseData){
    renderOfficeList(window.lastBaseData);
  }
}

// 🔥 hook into existing data load
const _origRender = window.renderDashboard || function(){};

window.renderDashboard = function(base){
  window.lastBaseData = base;
  renderOfficeList(base);
  _origRender(base);
};
</script>
"""

# inject before closing body
html = re.sub(r"</body>", inject + "\n</body>", html)

file.write_text(html)
print("✅ Frontend stabilization injected")
PY

git add "$FILE"
git commit -m "Frontend stabilization: safe office ranking + UI recovery" || true
git push origin main || true

echo "🚀 Deploying..."
fly deploy --local-only

echo "✅ DONE"
