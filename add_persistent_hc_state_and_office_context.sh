#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

SERVER="server.js"
FLY="fly.toml"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$SERVER" ] || { echo "Missing $SERVER"; exit 1; }
[ -f "$FLY" ] || { echo "Missing $FLY"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$SERVER" "$BACKUP_DIR/server.js.$STAMP.bak"
cp -f "$FLY" "$BACKUP_DIR/fly.toml.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

server = Path("server.js")
text = server.read_text(encoding="utf-8")

# 1) Persistent data root under /data if mounted
text = text.replace(
    "const HC_DATA_DIR = path.join(__dirname, 'data', 'hc-strategist');",
    "const HC_DATA_ROOT = process.env.TSM_DATA_ROOT || '/data';\nconst HC_DATA_DIR = path.join(HC_DATA_ROOT, 'hc-strategist');"
)

# 2) Add office-aware brief builder if not present
if "function buildOfficeContext(" not in text:
    helper = r"""
function buildOfficeContext(filtered = {}) {
  const ops = filtered.operations || {};
  const billing = filtered.billing || {};
  const insurance = filtered.insurance || {};
  const compliance = filtered.compliance || {};

  return {
    officeName: ops.officeName || billing.officeName || insurance.officeName || compliance.officeName || '',
    officeManager: ops.officeManager || billing.officeManager || insurance.officeManager || compliance.officeManager || '',
    persistentIssues: [
      ops.findings || null,
      billing.findings || null,
      insurance.findings || null,
      compliance.findings || null
    ].filter(Boolean),
    localConstraints: [
      ops.localConstraints || null,
      billing.localConstraints || null,
      insurance.localConstraints || null,
      compliance.localConstraints || null
    ].filter(Boolean),
    recentWins: [
      ops.recentWins || null,
      billing.recentWins || null,
      insurance.recentWins || null,
      compliance.recentWins || null
    ].filter(Boolean)
  };
}
"""
    marker = "function buildAudienceBrief("
    text = text.replace(marker, helper + "\n" + marker, 1)

# 3) Upgrade buildAudienceBrief to include office context
text = text.replace(
    "function buildAudienceBrief({ system, location, audience='om', format='brief', question='', filtered={}, result={} }) {",
    "function buildAudienceBrief({ system, location, audience='om', format='brief', question='', filtered={}, result={} }) {\n  const office = buildOfficeContext(filtered);"
)

text = text.replace(
    "const summaryLine = `Current cross-lane pressure is concentrated in ${top.map(t => t.nodeKey).join(', ') || 'the active operating lanes'}, with $${rev.toLocaleString()} at risk and $${cash14.toLocaleString()} in projected 14-day cash acceleration opportunity.`;",
    "const summaryLine = `Current cross-lane pressure is concentrated in ${top.map(t => t.nodeKey).join(', ') || 'the active operating lanes'}, with $${rev.toLocaleString()} at risk and $${cash14.toLocaleString()} in projected 14-day cash acceleration opportunity.`;\n  const officeLine = office.officeName ? `Office: ${office.officeName}` : '';\n  const managerLine = office.officeManager ? `Office manager: ${office.officeManager}` : '';"
)

text = text.replace(
    "System: ${system || 'General Healthcare'}\nLocation: ${location || 'All'}",
    "System: ${system || 'General Healthcare'}\nLocation: ${location || 'All'}${officeLine ? '\\n' + officeLine : ''}${managerLine ? '\\n' + managerLine : ''}"
)

text = text.replace(
    "Root cause:\n${rootCause || 'No live telemetry available.'}",
    "Root cause:\n${rootCause || 'No live telemetry available.'}${office.persistentIssues.length ? '\\n\\nPersistent issues:\\n- ' + office.persistentIssues.join('\\n- ') : ''}${office.localConstraints.length ? '\\n\\nLocal constraints:\\n- ' + office.localConstraints.join('\\n- ') : ''}${office.recentWins.length ? '\\n\\nRecent wins:\\n- ' + office.recentWins.join('\\n- ') : ''}"
)

# 4) Ensure node POST preserves office metadata fields naturally (already merges body)
# no change needed beyond allowing body fields to pass through

server.write_text(text, encoding="utf-8")
print("patched server.js")
PY

python3 <<'PY'
from pathlib import Path

p = Path("fly.toml")
text = p.read_text(encoding="utf-8")

if "[mounts]" not in text:
    text += """

[mounts]
  source = "tsm_shell_data"
  destination = "/data"
"""

p.write_text(text, encoding="utf-8")
print("patched fly.toml")
PY

echo "== VERIFY SYNTAX =="
node -c server.js

echo "== COMMIT =="
git add server.js fly.toml
git commit -m "Persist HC state and add office context to briefs" || true

echo "== PUSH =="
git push origin main

echo
echo "== IMPORTANT: CREATE FLY VOLUME ONCE =="
echo "Run this once if you have not created the volume yet:"
echo "fly volumes create tsm_shell_data --size 1 --region iad"

echo
echo "== DEPLOY =="
fly deploy

echo
echo "== TEST SEED WITH OFFICE CONTEXT =="
cat <<'CMDS'
curl -X POST https://tsm-shell.fly.dev/api/hc/nodes/operations \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "officeName":"Scottsdale Shea Office",
    "officeManager":"Dee Montee",
    "status":"ONLINE",
    "findings":"Intake delays and scheduling pressure are the main throughput blockers.",
    "summary":"Re-sequence intake coverage and clear queues older than 24 hours.",
    "bnca":"Re-sequence intake coverage, escalate aged queues, rebalance next shift.",
    "staffingCoverage":86,
    "queueDepth":31,
    "noShowRate":9.2,
    "intakeBacklog":18,
    "localConstraints":"Front-desk coverage is thin during first-shift handoff.",
    "recentWins":"Same-day queue clearance improved yesterday afternoon."
  }'

curl -X POST https://tsm-shell.fly.dev/api/hc/nodes/billing \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "officeName":"Scottsdale Shea Office",
    "officeManager":"Dee Montee",
    "status":"ONLINE",
    "findings":"Denial pressure and claim lag are slowing cash recovery.",
    "summary":"Prioritize high-value denials and scrub aging claims first.",
    "denialRate":12.4,
    "claimLagDays":6,
    "arOver30":185000
  }'

curl -X POST https://tsm-shell.fly.dev/api/hc/nodes/insurance \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "officeName":"Scottsdale Shea Office",
    "officeManager":"Dee Montee",
    "status":"ONLINE",
    "findings":"Prior auth backlog is delaying high-value claims.",
    "summary":"Escalate auths older than 48 hours.",
    "authBacklog":27,
    "authDelayHours":56,
    "pendingClaimsValue":240000
  }'
CMDS

echo
echo "== TEST OM / CFO BRIEFS =="
cat <<'CMDS'
curl -X POST https://tsm-shell.fly.dev/api/hc/brief \
  -H "Content-Type: application/json" \
  -d '{
    "system":"HonorHealth",
    "location":"Scottsdale - Shea",
    "audience":"om",
    "format":"status_update",
    "question":"What should I tell my director today?"
  }'

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
