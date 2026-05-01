#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

cp server.js "backups/server.js.hardfix.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

if "function filterHCState(" not in text:
    insertion_point = text.find("app.post(")  # before routes start

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

    if insertion_point != -1:
        text = text[:insertion_point] + helper + "\n" + text[insertion_point:]
    else:
        text += helper

    p.write_text(text, encoding="utf-8")
    print("✅ filterHCState injected at global scope")
else:
    print("⚠️ filterHCState already exists (skipped)")

PY

node -c server.js

git add server.js
git commit -m "Fix filterHCState scope (global)" || true
git pull --rebase origin main || true
git push origin main || true

fly deploy
