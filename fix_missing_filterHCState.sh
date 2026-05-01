#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js "backups/server.js.filterfix.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

helper = r"""
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

if "function filterHCState(" not in text:
    marker = "function normalizeOfficeState("
    if marker in text:
        text = text.replace(marker, helper + "\n" + marker, 1)
    else:
        text += "\n" + helper + "\n"

p.write_text(text, encoding="utf-8")
print("added filterHCState helper")
PY

node -c server.js
git add server.js
git commit -m "Add missing filterHCState helper" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
