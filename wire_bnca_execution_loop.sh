#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

SERVER="server.js"
PORTAL="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p backups/bnca_execution_loop
cp -f "$SERVER" "backups/bnca_execution_loop/server.$STAMP.bak"
cp -f "$PORTAL" "backups/bnca_execution_loop/honor-portal.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

server = Path("/workspaces/tsm-shell/server.js")
text = server.read_text(encoding="utf-8", errors="ignore")

# ---------- BACKEND INJECTION ----------
backend_block = r"""
/* ===== BNCA EXECUTION LOOP ===== */
global.HC_TASK_QUEUE = global.HC_TASK_QUEUE || [];

function buildBncaForOffice(office) {
  const officeName = office || "Scottsdale - Shea";

  const officeMap = {
    "Scottsdale - Shea": {
      riskScore: 92,
      denialRate: 12.4,
      authDelay: 56,
      queueDepth: 31,
      revenueAtRisk: 229850,
      recoverable72h: 78149,
      cashAcceleration14d: 109409,
      highestYieldLane: "Insurance",
      rootCause: [
        "Billing: denial 12.4% with lag 6d",
        "Insurance: auth backlog 27, delay 56h",
        "Operations: queue 31, backlog 18, staffing 86%"
      ],
      bestNextActions: [
        "Clear the highest-value backlog first",
        "Escalate auth and documentation blockers older than 24–72 hours",
        "Align intake, billing, and scheduling handoffs for the next shift"
      ],
      ownerLanes: ["Operations", "Billing", "Insurance"],
      summary: "HonorHealth risk is concentrated in Scottsdale - Shea. Highest-yield lane is Insurance. Immediate focus: Clear the highest-value backlog first.",
      recommendedAction: "Execute BNCA and assign recovery ownership"
    },
    "Mesa Family Practice": {
      riskScore: 84,
      denialRate: 9.8,
      authDelay: 22,
      queueDepth: 18,
      revenueAtRisk: 182000,
      recoverable72h: 62000,
      cashAcceleration14d: 98000,
      highestYieldLane: "Operations",
      rootCause: [
        "Operations: queue pressure and staffing gaps",
        "Billing: follow-up lag on aging claims",
        "Insurance: moderate auth friction"
      ],
      bestNextActions: [
        "Stabilize staffing and reduce queue pressure",
        "Push aged claims through billing follow-up",
        "Triage auth blockers by payer priority"
      ],
      ownerLanes: ["Operations", "Billing"],
      summary: "Mesa pressure is operational first, then billing throughput. Immediate focus: stabilize staffing and reduce queue pressure.",
      recommendedAction: "Stabilize OM operations and re-run BNCA"
    }
  };

  const d = officeMap[officeName] || officeMap["Scottsdale - Shea"];
  const bestOffice = officeName === "Scottsdale - Shea" ? "Mesa Family Practice" : "Scottsdale - Shea";

  return {
    ok: True,
    selectedOffice: officeName,
    actionView: "default",
    actionDetail: None,
    layer2: {
      ok: True,
      system: "HonorHealth",
      location: officeName,
      revenueAtRisk: d["revenueAtRisk"],
      recoverable72h: d["recoverable72h"],
      recoverable30d: int(d["recoverable72h"] * 2),
      cashAcceleration14d: d["cashAcceleration14d"],
      highestYieldLane: d["highestYieldLane"],
      rootCause: d["rootCause"],
      bestNextActions: d["bestNextActions"],
      ownerLanes: d["ownerLanes"],
      confidence: 91,
      summary: d["summary"]
    },
    actionBoard: {
      topPriorityNow: f"{officeName}: denial {d['denialRate']}% and AR>30 {d['revenueAtRisk']:,}",
      payerFocus: "Prior Authorization",
      strategistNarrative: d["summary"],
      actions: d["bestNextActions"],
      liveSignals: [
        {"title": "Denial Pressure", "urgency": "urgent", "detail": f"Denial {d['denialRate']}% with lag"},
        {"title": "Throughput", "urgency": "high", "detail": f"Queue {d['queueDepth']} · staffing pressure"},
        {"title": "Auth Friction", "urgency": "high", "detail": f"Delay {d['authDelay']}h"}
      ]
    },
    posture: {
      systemPosture: {
        overallRisk: "high",
        topRiskOffice: officeName,
        bestPerformingOffice: bestOffice,
        topSystemLane: d["highestYieldLane"],
        topSystemDriver: d["summary"],
        recoverable72hTotal: d["recoverable72h"] + 62000
      },
      officeRanking: [
        {
          "office": "Scottsdale - Shea",
          "riskRank": 1,
          "riskScore": 92,
          "status": "high",
          "summary": "Denial 12.4%, auth backlog 56h",
          "primaryDriver": "Denial + Auth",
          "recommendedAction": "Clear highest-value backlog first",
          "revenueAtRisk": 229850,
          "recoverable72h": 78149,
          "cashAcceleration14d": 109409
        },
        {
          "office": "Mesa Family Practice",
          "riskRank": 2,
          "riskScore": 84,
          "status": "medium",
          "summary": "Queue + staffing pressure",
          "primaryDriver": "Operations",
          "recommendedAction": "Stabilize staffing and reduce queue pressure",
          "revenueAtRisk": 182000,
          "recoverable72h": 62000,
          "cashAcceleration14d": 98000
        }
      ]
    },
    alerts: [
      {"type": "QUEUE_PRESSURE", "severity": "MEDIUM", "nodeKey": "operations", "message": f"{officeName}: queue depth {d['queueDepth']}"},
      {"type": "DENIAL_SPIKE", "severity": "HIGH", "nodeKey": "billing", "message": f"{officeName}: denial rate {d['denialRate']}%"},
      {"type": "AUTH_DELAY", "severity": "HIGH", "nodeKey": "insurance", "message": f"{officeName}: auth delay {d['authDelay']}h"}
    ]
  }

app.post('/api/hc/delegate', (req, res) => {
  const office = req.body?.office || 'Scottsdale - Shea';
  const action = req.body?.action || 'Execute BNCA';
  const ownerLane = req.body?.ownerLane || 'Billing/Insurance';
  const mode = req.body?.mode || 'bnca';

  const task = {
    id: Date.now(),
    office,
    action,
    ownerLane,
    mode,
    status: 'assigned',
    createdAt: new Date().toISOString()
  };

  global.HC_TASK_QUEUE.unshift(task);
  global.HC_TASK_QUEUE = global.HC_TASK_QUEUE.slice(0, 25);

  return res.json({ ok: true, task, queue: global.HC_TASK_QUEUE });
});

app.get('/api/hc/tasks', (_req, res) => {
  return res.json({ ok: true, tasks: global.HC_TASK_QUEUE || [] });
});

app.post('/api/hc/bnca', (req, res) => {
  const office = req.body?.office || 'Scottsdale - Shea';
  const mode = req.body?.mode || 'bnca';
  const data = buildBncaForOffice(office);

  if (mode === 'payer') {
    data["actionView"] = "auth";
    data["actionDetail"] = {
      "view": "auth",
      "title": "Payer Auth Escalation",
      "steps": [
        f"Pull all pending auth requests for {office} older than 24h",
        "Auth backlog: 27 cases · delay: 56h",
        "Call top 3 payers directly — prioritize Medicare/Prior Auth cases",
        "Submit peer-to-peer review requests for denials over $5,000",
        "Escalate unresolved auths >72h to medical director"
      ],
      "metric": {"label": "Auth Delay", "value": "56h", "target": "<24h"}
    };
  } else if (mode === 'brief') {
    data["actionView"] = "brief";
  } else if (mode === 'recovery') {
    data["actionView"] = "recovery";
  }

  return res.json(data);
});
/* ===== END BNCA EXECUTION LOOP ===== */
"""

if "/api/hc/delegate" not in text:
    # Append before module exports / end of file
    text = text + "\n\n" + backend_block + "\n"

server.write_text(text, encoding="utf-8")
print("backend endpoints wired")

# ---------- FRONTEND PATCH ----------
portal = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
html = portal.read_text(encoding="utf-8", errors="ignore")

# Add task queue panel if missing
task_panel = """
      <div class="block">
        <div class="railtitle">OM Task Queue</div>
        <div id="task-list" class="hc-list"><div class="muted" style="font-size:9px">No delegated tasks yet.</div></div>
      </div>
"""

if 'id="task-list"' not in html:
    html = html.replace(
        '</div>\n    </div>\n  </div>\n</div>',
        task_panel + '\n    </div>\n  </div>\n</div>',
        1
    )

# Replace delegate function
html = re.sub(
    r"function delegateToOM\(\)\{[^}]*\}",
    """async function delegateToOM(){
  try{
    const office = STATE.selectedOffice;
    const ownerLane = ((STATE.action && STATE.action.layer2 && STATE.action.layer2.ownerLanes) || ['Billing','Insurance']).join('/');
    const action = (STATE.action && STATE.action.actionBoard && STATE.action.actionBoard.topPriorityNow) || 'Execute BNCA';

    const res = await fetch('/api/hc/delegate', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        office,
        action,
        ownerLane,
        mode: STATE.mode
      })
    });

    const data = await res.json();
    if(data && data.ok){
      showToast('Delegated → ' + office);
      renderTasks(data.queue || []);
    } else {
      showToast('Delegate failed');
    }
  }catch(e){
    showToast('Delegate failed: ' + e.message);
  }
}""",
    html,
    count=1,
    flags=re.S
)

# Replace runModeAction
html = re.sub(
    r"function runModeAction\(\)\{[^}]*\}",
    """async function runModeAction(){
  try{
    const res = await fetch('/api/hc/bnca', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        office: STATE.selectedOffice,
        mode: STATE.mode
      })
    });
    STATE.action = await res.json();
    renderTop(STATE.base, STATE.action);
    renderHC(STATE.base, STATE.action);
    renderModes(STATE.base, STATE.action);
    showToast('BNCA refreshed → ' + STATE.selectedOffice);
  }catch(e){
    showToast('BNCA refresh failed: ' + e.message);
  }
}""",
    html,
    count=1,
    flags=re.S
)

# Add renderTasks + loadTasks if missing
if "function renderTasks(" not in html:
    inject = """
function renderTasks(tasks){
  const el = document.getElementById('task-list');
  if(!el) return;
  const list = tasks || [];
  el.innerHTML = list.length ? list.map(t => `
    <div class="hcbox">
      <div class="name" style="font-size:10px;color:var(--teal)">${esc(t.office)}</div>
      <div class="meta">${esc(t.action)}<br>Lane: ${esc(t.ownerLane)} · ${esc(t.status)}</div>
    </div>
  `).join('') : '<div class="muted" style="font-size:9px">No delegated tasks yet.</div>';
}

async function loadTasks(){
  try{
    const res = await fetch('/api/hc/tasks');
    const data = await res.json();
    renderTasks((data && data.tasks) || []);
  }catch(e){
    renderTasks([]);
  }
}
"""
    html = html.replace("window.addEventListener('load', refreshAll);", inject + "\nwindow.addEventListener('load', async () => { await refreshAll(); await loadTasks(); });")

# Ensure refreshAll doesn't clobber task list
html = html.replace("    renderModes(STATE.base, STATE.action);", "    renderModes(STATE.base, STATE.action);\n    await loadTasks();")

portal.write_text(html, encoding="utf-8")
print("frontend execution loop wired")
PY

git add server.js html/honor-portal/index.html
git commit -m "Wire BNCA execution loop across honor portal and hc command" || true
git push origin main || true
fly deploy --local-only
