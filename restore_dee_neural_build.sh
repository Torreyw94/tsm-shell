#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

SRC="backups/honor-portal.index.html.20260421-220635.bak"
DST="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$SRC" ] || { echo "Missing source backup: $SRC"; exit 1; }
[ -f "$DST" ] || { echo "Missing destination file: $DST"; exit 1; }

mkdir -p backups/restore_dee_neural
cp -f "$DST" "backups/restore_dee_neural/honor-portal.index.before.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

src = Path("/workspaces/tsm-shell/backups/honor-portal.index.html.20260421-220635.bak").read_text(encoding="utf-8", errors="ignore")
dst_path = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
dst = dst_path.read_text(encoding="utf-8", errors="ignore")

# --- helpers ---
def extract(pattern, text, flags=re.S):
    m = re.search(pattern, text, flags)
    return m.group(0) if m else None

def inject_before_body(html, block):
    if not block:
        return html
    if block in html:
        return html
    if "</body>" in html:
        return html.replace("</body>", block + "\n</body>", 1)
    return html + "\n" + block

# 1) Restore the HC-only profile lock banner/snippet if present
profile_banner = extract(r".{0,300}HC Strategist online — HonorHealth profile locked\. Cross-sector bleed: OFF\..{0,300}", src)
if profile_banner and "Cross-sector bleed: OFF" not in dst:
    notice = f"""
<div id="dee-profile-lock" style="margin:12px 0;padding:10px 14px;border:1px solid rgba(0,255,140,.18);border-radius:10px;background:rgba(0,255,140,.05);color:#bfffe0;font-size:13px;">
HC Strategist online — HonorHealth profile locked. Cross-sector bleed: OFF. Ask about denials, auths, offices, appeals, or revenue.
</div>
"""
    dst = inject_before_body(dst, notice)

# 2) Restore scoped profile config if not present
if "HonorHealth" in src and "officeManager" in src and "officeManager: 'Dee Montee'" in src and "officeManager" not in dst:
    profile_block = """
<script>
window.HONOR_SCOPE = {
  system: 'HonorHealth',
  officeManager: 'Dee Montee',
  sector: 'healthcare',
  allowedNodes: [
    'hc-billing','hc-compliance','hc-insurance','hc-medical',
    'hc-pharmacy','hc-grants','hc-vendors','hc-strategist',
    'hc-command','hc-taxprep'
  ],
  offices: ['Scottsdale','Mesa','Tempe','North Mountain'],
  crossSectorBleed: false
};
</script>
"""
    dst = inject_before_body(dst, profile_block)

# 3) Restore pack definitions if not present
if "Pull HonorHealth Revenue Pack" in src and "window.HONOR_PACKS" not in dst:
    packs_block = """
<script>
window.HONOR_PACKS = {
  revenue: `Pull HonorHealth Revenue Pack. Synthesize HC-Billing, HC-Insurance, HC-Compliance + all 4 office summaries. Metrics: denial_rate, claims_aging, payer_auth_pending, modifier_overuse, documentation_gap_rate. Return top 5 revenue risks ranked by dollar impact.`,
  variance: `Pull HonorHealth Office Variance Pack. Compare Scottsdale, Mesa, Tempe, North Mountain. Metrics: denial_rate, auth_delay, coding_drift, writeoff_risk. Which office needs immediate intervention and why? What should each OM do this week?`,
  denial: `Pull Denial Recovery Pack. Prioritize payer-specific denial recovery by deadline and dollar impact.`,
  auth: `Pull Auth Friction Pack. Identify payer bottlenecks, pending auth concentration, and workflow fixes.`,
  executive: `Pull Executive Brief Pack. Synthesize all HonorHealth HC data into a 5-point executive brief: overall health score, top risk, top win, 3 actions for today, 1 strategic recommendation for this month.`
};
</script>
"""
    dst = inject_before_body(dst, packs_block)

# 4) Restore quick actions if not present
if "single highest-priority action Dee Montee" in src and "window.HONOR_QUICK" not in dst:
    quick_block = """
<script>
window.HONOR_QUICK = {
  priority: `What is the single highest-priority action Dee Montee at HonorHealth should take in the next hour? Consider urgent denial deadlines, auth backlog, and office variance. Return: action, why it is first, who acts.`,
  executive: `Generate an executive summary for HonorHealth with integrated HC Strategist recommendations. Include current performance metrics, top 3 risks, top 3 opportunities, and 5 actions ranked by ROI.`,
  team: `Build a team briefing for HonorHealth revenue cycle staff. Include top issues, compliance items, and action items by role.`,
  appeals: `Generate payer-specific appeal strategy for the highest-value denials. Include documentation requirements, deadline rules, and sequencing.`
};
</script>
"""
    dst = inject_before_body(dst, quick_block)

# 5) Restore neural helpers
if "function quickAsk(" not in dst:
    helper_block = """
<script>
async function quickAsk(promptText){
  try{
    const out = document.querySelector('[data-email="brief"]') || document.querySelector('#exec-out') || document.body;
    const res = await fetch('/api/hc/brief', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({
        system: 'HonorHealth',
        location: 'Scottsdale - Shea',
        audience: 'cfo',
        format: 'email',
        question: promptText
      })
    });
    const data = await res.json();
    if(data && data.brief){
      const target = out.parentElement || out;
      target.innerHTML = '<div style="white-space:pre-wrap;line-height:1.7;">' + data.brief + '</div>';
    }
  }catch(e){
    console.warn('quickAsk failed:', e.message);
  }
}
</script>
"""
    dst = inject_before_body(dst, helper_block)

dst_path.write_text(dst, encoding="utf-8")
print("restored Dee neural layer into live honor portal")
PY

echo "== VERIFY =="
grep -n "Cross-sector bleed: OFF\|HONOR_SCOPE\|HONOR_PACKS\|HONOR_QUICK\|quickAsk" "$DST" || true

echo "== COMMIT =="
git add "$DST"
git commit -m "Restore Dee neural HonorHealth profile layer" || true

echo "== PUSH =="
git push origin main || true

echo "== DEPLOY =="
fly deploy
