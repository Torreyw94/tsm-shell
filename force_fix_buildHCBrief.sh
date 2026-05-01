#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js "backups/server.js.brief.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

text = re.sub(
    r"\nfunction buildHCBrief\([\s\S]*?\n\}\n",
    "\n",
    text,
    count=1
)

helper = """

function buildHCBrief({ system = '', location = '', question = '' }) {
  return {
    subject: `${location} Revenue Pressure Update`,
    body: `System: ${system}

Location: ${location}

Summary:
Revenue pressure is being driven by billing, insurance, and operational constraints.

Key Focus:
- Reduce denial backlog
- Accelerate auth processing
- Stabilize intake throughput

Executive Direction:
Immediate intervention recommended in high-risk lanes.

Question Context:
${question}
`
  };
}
"""

m = re.search(r"\napp\.(get|post|use)\(", text)
idx = m.start()

text = text[:idx] + helper + "\n" + text[idx:]

p.write_text(text, encoding="utf-8")
print("force-inserted top-level buildHCBrief")
PY

node -c server.js
grep -n "function buildHCBrief" server.js

git add server.js
git commit -m "Force top-level buildHCBrief helper" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
