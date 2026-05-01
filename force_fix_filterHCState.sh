#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js "backups/server.js.forcefilter.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

# Remove any existing broken helper block if present
text = re.sub(
    r"\n// ===============================\n// HC STATE FILTER \(GLOBAL HELPER\)\n// ===============================\nfunction filterHCState\(state = \{\}, system = '', location = ''\) \{[\s\S]*?\n\}\n",
    "\n",
    text,
    count=1
)

helper = """

// ===============================
// HC STATE FILTER (GLOBAL HELPER)
// ===============================
function filterHCState(state = {}, system = '', location = '') {
  const out = {};
  for (const [nodeKey, node] of Object.entries(state || {})) {
    if (!node || typeof node !== 'object') continue;

    const nodeSystem = String(node.system || '').trim();
    const nodeLocation = String(node.location || '').trim();

    const systemOk = !system || nodeSystem === system;
    const locationOk = !location || nodeLocation === location;

    if (systemOk && locationOk) {
      out[nodeKey] = node;
    }
  }
  return out;
}

"""

# Force insert at true top-level before first route
m = re.search(r"\napp\.(get|post|use)\(", text)
if not m:
    raise SystemExit("Could not find route insertion point")

idx = m.start()
text = text[:idx] + helper + text[idx:]

p.write_text(text, encoding="utf-8")
print("force-inserted top-level filterHCState")
PY

node -c server.js
grep -n "function filterHCState\|filterHCState(" server.js

git add server.js
git commit -m "Force top-level filterHCState helper" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
