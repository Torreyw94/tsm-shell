#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
mkdir -p backups/music_regex_fix
cp -f server.js "backups/music_regex_fix/server.$(date +%Y%m%d-%H%M%S).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

clean_fn = r'''function cleanAgentText(text){
  return String(text || "")
    .replace(/\[(ZAY|RIYA|DJ)[^\]]*\]/g, "")
    .replace(/^Agent move:.*$/gm, "")
    .replace(/^Cadence note:.*$/gm, "")
    .replace(/^Tone note:.*$/gm, "")
    .replace(/^Arrangement note:.*$/gm, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}
'''

# Replace a complete or corrupted cleanAgentText block.
if "function cleanAgentText(text)" in text:
    start = text.find("function cleanAgentText(text)")
    next_fn = text.find("\nfunction agentPass", start)
    if next_fn == -1:
        raise SystemExit("Could not find function agentPass after cleanAgentText")
    text = text[:start] + clean_fn + "\n" + text[next_fn+1:]
else:
    marker = "function agentPass(agent, draft, request)"
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit("Could not find agentPass marker")
    text = text[:idx] + clean_fn + "\n" + text[idx:]

p.write_text(text, encoding="utf-8")
print("cleanAgentText repaired safely")
PY

node -c server.js

git add server.js
git commit -m "Fix cleanAgentText regex and restore server syntax" || true
git push origin main
fly deploy --local-only

echo "Testing endpoints..."
curl -s https://tsm-shell.fly.dev/api/music/evolution
echo
curl -s -X POST https://tsm-shell.fly.dev/api/music/agent/chain \
  -H "Content-Type: application/json" \
  -d '{"draft":"Life surrounded by wrong but trying to stay right is a fight\nEvery day a battle every night a new light","request":"full chain"}'
echo
