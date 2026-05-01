#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

SERVER="server.js"
UI="html/hc-strategist/index.html"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$SERVER" ] || { echo "Missing $SERVER"; exit 1; }
[ -f "$UI" ] || { echo "Missing $UI"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$SERVER" "$BACKUP_DIR/server.js.$STAMP.bak"
cp -f "$UI" "$BACKUP_DIR/hc-strategist.index.html.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

server = Path("server.js")
ui = Path("html/hc-strategist/index.html")

# ---------------------------
# PATCH server.js
# ---------------------------
s = server.read_text(encoding="utf-8")

brief_helpers = r"""
function buildAudienceBrief({ system, location, audience='om', format='brief', question='', filtered={}, result={} }) {
  const top = result.top || [];
  const topLane = result.highestYieldLane || (top[0]?.nodeKey ? top[0].nodeKey.charAt(0).toUpperCase() + top[0].nodeKey.slice(1) : 'Unassigned');
  const rev = Number(result.revenueAtRisk || 0);
  const rec72 = Number(result.recoverable72h || 0);
  const rec30 = Number(result.recoverable30d || 0);
  const cash14 = Number(result.cashAcceleration14d || 0);

  const ops = filtered.operations || {};
  const billing = filtered.billing || {};
  const insurance = filtered.insurance || {};
  const compliance = filtered.compliance || {};

  const rootCause = [
    billing.denialRate != null || billing.claimLagDays != null
      ? `Billing is showing denial pressure at ${billing.denialRate ?? 'N/A'}% with claim lag at ${billing.claimLagDays ?? 'N/A'} days.`
      : null,
    insurance.authBacklog != null || insurance.authDelayHours != null
      ? `Insurance is carrying ${insurance.authBacklog ?? 'N/A'} pending auth items with an average delay of ${insurance.authDelayHours ?? 'N/A'} hours.`
      : null,
    ops.queueDepth != null || ops.intakeBacklog != null || ops.staffingCoverage != null
      ? `Operations is reporting queue depth ${ops.queueDepth ?? 'N/A'}, intake backlog ${ops.intakeBacklog ?? 'N/A'}, and staffing coverage ${ops.staffingCoverage ?? 'N/A'}%.`
      : null,
    compliance.openFindings != null || compliance.auditExposure != null
      ? `Compliance is carrying ${compliance.openFindings ?? 'N/A'} open findings with audit exposure of $${compliance.auditExposure ?? 'N/A'}.`
      : null
  ].filter(Boolean).join(' ');

  const actions = [
    'Clear the highest-value backlog first.',
    'Escalate aged auth and documentation blockers older than 24–72 hours.',
    'Align intake, billing, and scheduling handoffs for the next shift.'
  ];

  const summaryLine = `Current cross-lane pressure is concentrated in ${top.map(t => t.nodeKey).join(', ') || 'the active operating lanes'}, with $${rev.toLocaleString()} at risk and $${cash14.toLocaleString()} in projected 14-day cash acceleration opportunity.`;

  const audiencePrefix = {
    om: 'Operational summary for office management:',
    director: 'Cross-functional leadership summary:',
    cfo: 'Financial impact summary:',
    ceo: 'Executive summary:'
  }[audience] || 'Leadership summary:';

  if (format === 'status_update') {
    return `${audiencePrefix}

System: ${system || 'General Healthcare'}
Location: ${location || 'All'}

Top issue: ${top.map(t => t.nodeKey).join(' + ') || 'No qualifying node pressure found'}
Highest-yield lane: ${topLane}
Revenue at risk: $${rev.toLocaleString()}
Recoverable in 72 hours: $${rec72.toLocaleString()}
Projected 14-day cash acceleration: $${cash14.toLocaleString()}

Root cause:
${rootCause || 'No live telemetry available.'}

Immediate actions:
1. ${actions[0]}
2. ${actions[1]}
3. ${actions[2]}`;
  }

  if (format === 'talking_points') {
    return `TALKING POINTS

• ${summaryLine}
• Highest-yield lane right now is ${topLane}.
• Recoverable value is $${rec72.toLocaleString()} in 72 hours and $${rec30.toLocaleString()} in 30 days.
• Root cause is cross-functional: ${rootCause || 'no live telemetry available.'}
• Immediate response is to ${actions[0].toLowerCase()} ${actions[1].toLowerCase()} ${actions[2].toLowerCase()}`;
  }

  if (format === 'email') {
    return `Subject: ${location || 'Site'} Revenue Pressure Update

Team,

This is a current update for ${system || 'General Healthcare'}${location ? ' — ' + location : ''}.

${summaryLine}

Highest-yield lane at this time is ${topLane}. Estimated recoverable value is $${rec72.toLocaleString()} in the next 72 hours and $${rec30.toLocaleString()} over 30 days.

Root cause:
${rootCause || 'No live telemetry available.'}

Current response plan:
1. ${actions[0]}
2. ${actions[1]}
3. ${actions[2]}

Please let me know if you would like this converted into a more detailed operating brief.

Thanks,`;
  }

  return `${audiencePrefix}

${summaryLine}

Highest-yield lane: ${topLane}
Revenue at risk: $${rev.toLocaleString()}
Recoverable value:
- 72 hours: $${rec72.toLocaleString()}
- 30 days: $${rec30.toLocaleString()}

Root cause:
${rootCause || 'No live telemetry available.'}

Recommended next actions:
1. ${actions[0]}
2. ${actions[1]}
3. ${actions[2]}

Question context:
${question || 'No additional question provided.'}`;
}

"""

brief_route = r"""
app.post('/api/hc/brief', (req, res) => {
  try {
    const {
      system = '',
      location = '',
      audience = 'om',
      format = 'brief',
      question = ''
    } = req.body || {};

    const state = readJson(HC_NODE_STATE_FILE, {});
    const filtered = Object.fromEntries(
      Object.entries(state).filter(([_, n]) =>
        (!system || (n.system || '') === system) &&
        (!location || location === 'All' || (n.location || '') === location)
      )
    );

    const result = aggregateLayer2(filtered);

    const highestYieldLane =
      result.top?.[0]?.nodeKey
        ? result.top[0].nodeKey.charAt(0).toUpperCase() + result.top[0].nodeKey.slice(1)
        : 'Unassigned';

    result.highestYieldLane = highestYieldLane;
    result.cashAcceleration14d = result.cashAcceleration14d || Math.round((result.recoverable30d || 0) * 0.7);

    const brief = buildAudienceBrief({
      system,
      location,
      audience,
      format,
      question,
      filtered,
      result
    });

    res.json({
      ok: true,
      brief,
      audience,
      format,
      system,
      location,
      revenueAtRisk: result.revenueAtRisk || 0,
      recoverable72h: result.recoverable72h || 0,
      recoverable30d: result.recoverable30d || 0,
      cashAcceleration14d: result.cashAcceleration14d || 0,
      highestYieldLane
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});
"""

if "function buildAudienceBrief(" not in s:
    marker = "app.post('/api/hc/layer2'"
    if marker in s:
        s = s.replace(marker, brief_helpers + "\n" + marker, 1)
    else:
        s += "\n" + brief_helpers + "\n"

if "app.post('/api/hc/brief'" not in s:
    marker = "app.post('/api/hc/ask'"
    if marker in s:
        s = s.replace(marker, brief_route + "\n\n" + marker, 1)
    else:
        s += "\n" + brief_route + "\n"

server.write_text(s, encoding="utf-8")

# ---------------------------
# PATCH html/hc-strategist/index.html
# ---------------------------
h = ui.read_text(encoding="utf-8")

nav_btn = """
<button class="nav-btn" onclick="switchTab('exec', this)">📨 EXEC CORRESPONDENCE</button>
"""

exec_tab = """
<div id="tab-exec">
  <div class="ai-box" style="margin-top:16px">
    <div class="ai-hdr">📨 EXEC CORRESPONDENCE</div>
    <div class="ai-row" style="gap:10px; flex-wrap:wrap; margin-bottom:10px;">
      <select id="brief-audience" class="ai-inp" style="max-width:180px">
        <option value="om">OM</option>
        <option value="director">Director</option>
        <option value="cfo">CFO</option>
        <option value="ceo">CEO</option>
      </select>
      <select id="brief-format" class="ai-inp" style="max-width:200px">
        <option value="brief">Brief</option>
        <option value="email">Email</option>
        <option value="status_update">Status Update</option>
        <option value="talking_points">Talking Points</option>
      </select>
    </div>
    <div class="ai-row" style="margin-bottom:10px;">
      <input id="brief-question" class="ai-inp" type="text" placeholder="What are you being asked about?" />
      <button class="ai-btn" onclick="generateLeadershipBrief()">GENERATE LEADERSHIP BRIEF</button>
      <button class="ai-btn" onclick="copyLeadershipBrief()">COPY</button>
    </div>
    <div id="brief-res" class="ai-res">> Leadership brief ready.</div>
  </div>
</div>
"""

script_patch = """
async function generateLeadershipBrief() {
  const out = document.getElementById('brief-res');
  if (!out) return;

  const system =
    document.getElementById('system-filter')?.value ||
    'HonorHealth';

  const location =
    document.getElementById('location-filter')?.value ||
    'Scottsdale - Shea';

  const audience =
    document.getElementById('brief-audience')?.value ||
    'om';

  const format =
    document.getElementById('brief-format')?.value ||
    'brief';

  const question =
    document.getElementById('brief-question')?.value ||
    '';

  out.innerHTML = '⏳ Generating leadership brief...';

  try {
    const res = await fetch('/api/hc/brief', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ system, location, audience, format, question })
    });

    const data = await res.json();
    if (!data.ok) throw new Error(data.error || 'Brief generation failed');

    out.innerHTML = (data.brief || 'No brief returned.').replace(/\\n/g, '<br>');
  } catch (err) {
    out.innerHTML = '&gt; Leadership brief error: ' + err.message;
  }
}

function copyLeadershipBrief() {
  const el = document.getElementById('brief-res');
  if (!el) return;
  const text = el.innerText || el.textContent || '';
  navigator.clipboard.writeText(text).catch(() => {});
}
"""

if "EXEC CORRESPONDENCE" not in h:
    marker = "PRESENTATION MODE"
    idx = h.find(marker)
    if idx != -1:
        btn_insert = h.rfind("<button", 0, idx)
        if btn_insert != -1:
            h = h[:btn_insert] + nav_btn + h[btn_insert:]
        else:
            h += "\n" + nav_btn
    else:
        h += "\n" + nav_btn

if 'id="tab-exec"' not in h:
    if "</body>" in h:
        h = h.replace("</body>", exec_tab + "\n</body>", 1)
    else:
        h += "\n" + exec_tab

if "async function generateLeadershipBrief()" not in h:
    if "</script>" in h:
        h = h.replace("</script>", script_patch + "\n</script>", 1)
    else:
        h += "\n<script>\n" + script_patch + "\n</script>\n"

ui.write_text(h, encoding="utf-8")
print("patched server.js and html/hc-strategist/index.html")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== COMMIT =="
git add server.js html/hc-strategist/index.html
git commit -m "Add hc brief endpoint and exec correspondence tab" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "== TEST BRIEF ENDPOINT =="
cat <<'CMDS'
curl -X POST https://tsm-shell.fly.dev/api/hc/brief \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "audience":"cfo",
    "format":"email",
    "question":"What is driving current revenue pressure and what are we doing about it?"
  }'
CMDS

echo
echo "Open:"
echo "https://tsm-shell.fly.dev/html/hc-strategist/"
echo
echo "Then click:"
echo "EXEC CORRESPONDENCE"
