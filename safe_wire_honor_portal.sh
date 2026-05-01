#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

FILE="html/honor-portal/index.html"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$FILE" ] || { echo "Missing $FILE"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$FILE" "$BACKUP_DIR/honor-portal.index.html.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/honor-portal/index.html")
text = p.read_text(encoding="utf-8")

# Remove previously broken diff-style insertions if they somehow landed
clean_lines = []
for line in text.splitlines():
    if line.startswith("+++ ") or line.startswith("--- ") or line.startswith("@@ "):
        continue
    if line.startswith("+<div id=\"honor-neural-panel\"") or line.startswith("+<script>"):
        clean_lines.append(line[1:])
    elif line.startswith("+") and "honor-" in line:
        clean_lines.append(line[1:])
    else:
        clean_lines.append(line)
text = "\n".join(clean_lines)

panel = """
<div id="honor-neural-panel" style="margin:24px 0;padding:18px;border:1px solid rgba(255,255,255,0.08);border-radius:12px;background:rgba(6,12,22,0.85);color:#d9e7ff;font-family:Arial,sans-serif;">
  <div style="display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:16px;">
    <div>
      <div style="font-size:12px;letter-spacing:.12em;color:#7aa2ff;text-transform:uppercase;">Honor Neural Link</div>
      <div style="font-size:22px;font-weight:700;">Scottsdale Shea Office</div>
      <div style="font-size:13px;color:#9fb4d9;">Office Manager: Dee Montee · System: HonorHealth</div>
    </div>
    <div style="display:flex;gap:10px;flex-wrap:wrap;">
      <button onclick="loadHonorPortalIntel()" style="padding:10px 14px;border-radius:10px;border:1px solid rgba(255,255,255,0.1);background:#0f1e36;color:#fff;cursor:pointer;">Refresh Live Intelligence</button>
      <button onclick="generateHonorExecBrief()" style="padding:10px 14px;border-radius:10px;border:1px solid rgba(255,255,255,0.1);background:#163d2b;color:#fff;cursor:pointer;">Generate CFO Email</button>
      <button onclick="copyHonorExecBrief()" style="padding:10px 14px;border-radius:10px;border:1px solid rgba(255,255,255,0.1);background:#3b2c13;color:#fff;cursor:pointer;">Copy Brief</button>
    </div>
  </div>

  <div style="display:grid;grid-template-columns:repeat(4,minmax(140px,1fr));gap:12px;margin-bottom:18px;">
    <div style="padding:12px;border-radius:10px;background:rgba(255,255,255,0.04);">
      <div style="font-size:11px;color:#8ea0c7;text-transform:uppercase;">Revenue At Risk</div>
      <div id="honor-risk" style="font-size:24px;font-weight:700;">—</div>
    </div>
    <div style="padding:12px;border-radius:10px;background:rgba(255,255,255,0.04);">
      <div style="font-size:11px;color:#8ea0c7;text-transform:uppercase;">72h Recoverable</div>
      <div id="honor-rec72" style="font-size:24px;font-weight:700;">—</div>
    </div>
    <div style="padding:12px;border-radius:10px;background:rgba(255,255,255,0.04);">
      <div style="font-size:11px;color:#8ea0c7;text-transform:uppercase;">14d Cash Acceleration</div>
      <div id="honor-14d" style="font-size:24px;font-weight:700;">—</div>
    </div>
    <div style="padding:12px;border-radius:10px;background:rgba(255,255,255,0.04);">
      <div style="font-size:11px;color:#8ea0c7;text-transform:uppercase;">Highest-Yield Lane</div>
      <div id="honor-lane" style="font-size:24px;font-weight:700;">—</div>
    </div>
  </div>

  <div style="display:grid;grid-template-columns:1.1fr 1fr;gap:16px;align-items:start;">
    <div>
      <div style="margin-bottom:14px;padding:14px;border-radius:10px;background:rgba(255,255,255,0.04);">
        <div style="font-size:12px;letter-spacing:.08em;color:#7aa2ff;text-transform:uppercase;margin-bottom:8px;">Live Office State</div>
        <div id="honor-state" style="white-space:pre-wrap;line-height:1.6;font-size:14px;">Loading live office state...</div>
      </div>

      <div style="padding:14px;border-radius:10px;background:rgba(255,255,255,0.04);">
        <div style="font-size:12px;letter-spacing:.08em;color:#7aa2ff;text-transform:uppercase;margin-bottom:8px;">Enterprise BNCA</div>
        <div id="honor-bnca" style="white-space:pre-wrap;line-height:1.6;font-size:14px;">Awaiting BNCA...</div>
      </div>
    </div>

    <div>
      <div style="margin-bottom:14px;padding:14px;border-radius:10px;background:rgba(255,255,255,0.04);">
        <div style="font-size:12px;letter-spacing:.08em;color:#7aa2ff;text-transform:uppercase;margin-bottom:8px;">Executive Correspondence</div>
        <div id="honor-brief" style="white-space:pre-wrap;line-height:1.6;font-size:14px;">Awaiting leadership brief...</div>
      </div>

      <div style="padding:14px;border-radius:10px;background:rgba(255,255,255,0.04);">
        <div style="font-size:12px;letter-spacing:.08em;color:#7aa2ff;text-transform:uppercase;margin-bottom:8px;">Action Plan</div>
        <div id="honor-actions" style="white-space:pre-wrap;line-height:1.6;font-size:14px;">1. Clear highest-value backlog first
2. Escalate auth/documentation blockers older than 24–72 hours
3. Align intake → billing → scheduling handoffs</div>
      </div>
    </div>
  </div>
</div>
"""

script = """
<script>
const HONOR_SCOPE = {
  system: 'HonorHealth',
  location: 'Scottsdale - Shea',
  officeManager: 'Dee Montee',
  officeName: 'Scottsdale Shea Office'
};

async function fetchHonorState() {
  const url = `/api/hc/nodes/filter?system=${encodeURIComponent(HONOR_SCOPE.system)}&location=${encodeURIComponent(HONOR_SCOPE.location)}`;
  const res = await fetch(url);
  return await res.json();
}

async function fetchHonorLayer2() {
  const res = await fetch('/api/hc/layer2', {
    method: 'POST',
    headers: { 'Content-Type':'application/json' },
    body: JSON.stringify({
      system: HONOR_SCOPE.system,
      location: HONOR_SCOPE.location
    })
  });
  return await res.json();
}

async function fetchHonorBrief() {
  const res = await fetch('/api/hc/brief', {
    method: 'POST',
    headers: { 'Content-Type':'application/json' },
    body: JSON.stringify({
      system: HONOR_SCOPE.system,
      location: HONOR_SCOPE.location,
      audience: 'cfo',
      format: 'email',
      question: 'What is driving current revenue pressure and what are we doing about it?'
    })
  });
  return await res.json();
}

function fmtMoney(v) {
  const n = Number(v || 0);
  return '$' + n.toLocaleString();
}

function renderHonorState(data) {
  const el = document.getElementById('honor-state');
  if (!el) return;

  const s = data?.state || {};
  const lines = [];

  if (s.operations) {
    lines.push(`OPERATIONS
- ${s.operations.findings || 'No findings'}
- Queue: ${s.operations.queueDepth ?? 'N/A'}
- Intake Backlog: ${s.operations.intakeBacklog ?? 'N/A'}
- Staffing: ${s.operations.staffingCoverage ?? 'N/A'}%`);
  }

  if (s.billing) {
    lines.push(`BILLING
- ${s.billing.findings || 'No findings'}
- Denial Rate: ${s.billing.denialRate ?? 'N/A'}%
- Claim Lag: ${s.billing.claimLagDays ?? 'N/A'}d
- AR > 30: ${s.billing.arOver30 != null ? fmtMoney(s.billing.arOver30) : 'N/A'}`);
  }

  if (s.insurance) {
    lines.push(`INSURANCE
- ${s.insurance.findings || 'No findings'}
- Auth Backlog: ${s.insurance.authBacklog ?? 'N/A'}
- Delay: ${s.insurance.authDelayHours ?? 'N/A'}h
- Pending Claims: ${s.insurance.pendingClaimsValue != null ? fmtMoney(s.insurance.pendingClaimsValue) : 'N/A'}`);
  }

  el.textContent = lines.length ? lines.join('\\n\\n') : 'No live office state available.';
}

function renderHonorLayer2(data) {
  const out = document.getElementById('honor-bnca');
  if (out) out.textContent = data?.output || 'No BNCA available.';

  const risk = document.getElementById('honor-risk');
  const rec72 = document.getElementById('honor-rec72');
  const d14 = document.getElementById('honor-14d');
  const lane = document.getElementById('honor-lane');

  if (risk) risk.textContent = fmtMoney(data?.revenueAtRisk);
  if (rec72) rec72.textContent = fmtMoney(data?.recoverable72h);
  if (d14) d14.textContent = fmtMoney(data?.cashAcceleration14d);
  if (lane) lane.textContent = data?.highestYieldLane || 'Unassigned';
}

function renderHonorBrief(data) {
  const out = document.getElementById('honor-brief');
  if (!out) return;
  out.textContent = data?.brief || 'No leadership brief available.';
}

async function loadHonorPortalIntel() {
  const stateEl = document.getElementById('honor-state');
  const bncaEl = document.getElementById('honor-bnca');
  const briefEl = document.getElementById('honor-brief');

  if (stateEl) stateEl.textContent = 'Loading live office state...';
  if (bncaEl) bncaEl.textContent = 'Running enterprise BNCA...';
  if (briefEl) briefEl.textContent = 'Generating leadership brief...';

  try {
    const [state, layer2, brief] = await Promise.all([
      fetchHonorState(),
      fetchHonorLayer2(),
      fetchHonorBrief()
    ]);

    renderHonorState(state);
    renderHonorLayer2(layer2);
    renderHonorBrief(brief);
  } catch (e) {
    if (stateEl) stateEl.textContent = 'Error loading office intelligence.';
    if (bncaEl) bncaEl.textContent = 'Error running BNCA.';
    if (briefEl) briefEl.textContent = 'Error generating leadership brief.';
    console.error(e);
  }
}

function generateHonorExecBrief() {
  fetchHonorBrief().then(renderHonorBrief).catch(console.error);
}

function copyHonorExecBrief() {
  const el = document.getElementById('honor-brief');
  if (!el) return;
  navigator.clipboard.writeText(el.innerText || el.textContent || '').catch(() => {});
}

window.addEventListener('load', () => {
  loadHonorPortalIntel();
  setInterval(loadHonorPortalIntel, 15000);
});
</script>
"""

# Only insert once
if "id=\"honor-neural-panel\"" not in text:
    if "</body>" in text:
        text = text.replace("</body>", panel + "\n" + script + "\n</body>", 1)
    else:
        text += "\n" + panel + "\n" + script

p.write_text(text, encoding="utf-8")
print("patched html/honor-portal/index.html")
PY

echo "== REVIEW DIFF =="
git diff -- "$FILE" || true

echo "== COMMIT =="
git add "$FILE"
git commit -m "Wire honor portal to live hc strategist endpoints" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "Open:"
echo "https://tsm-shell.fly.dev/html/honor-portal/"
