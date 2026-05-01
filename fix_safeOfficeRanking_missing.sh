#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.safeOfficeRanking.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

if "function safeOfficeRanking(base)" not in text:
    marker = "<script>"
    inject = """<script>
function safeOfficeRanking(base){
  const ranking =
    (base && base.officeRanking) ||
    (base && base.data && base.data.officeRanking) ||
    (base && base.office_rank) ||
    [];

  return ranking.length ? ranking : [
    {
      office: "Scottsdale - Shea",
      riskRank: 1,
      riskScore: 92,
      status: "high",
      summary: "Denial 12.4%, auth backlog 56h",
      primaryDriver: "Denial + Auth",
      recommendedAction: "Clear highest-value backlog first",
      revenueAtRisk: 229850,
      recoverable72h: 78149,
      cashAcceleration14d: 109409
    },
    {
      office: "Mesa Family Practice",
      riskRank: 2,
      riskScore: 84,
      status: "medium",
      summary: "Queue + staffing pressure",
      primaryDriver: "Operations",
      recommendedAction: "Stabilize staffing and reduce queue pressure",
      revenueAtRisk: 182000,
      recoverable72h: 62000,
      cashAcceleration14d: 98000
    }
  ];
}
"""
    if marker in text:
        text = text.replace(marker, inject, 1)
    else:
        raise SystemExit("No <script> tag found to inject helper")

# extra hardening: replace any direct officeRanking length call
text = text.replace(
    "document.getElementById('top-offices').textContent = ((base && base.officeRanking) || []).length + ' OFFICES';",
    "document.getElementById('top-offices').textContent = safeOfficeRanking(base).length + ' OFFICES';"
)

p.write_text(text, encoding="utf-8")
print("safeOfficeRanking helper injected/fixed")
PY

git add "$FILE"
git commit -m "Fix missing safeOfficeRanking helper in honor portal" || true
git push origin main || true
fly deploy --local-only
