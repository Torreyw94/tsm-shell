#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
mkdir -p backups/music_agentpass_fix
cp -f server.js "backups/music_agentpass_fix/server.$(date +%Y%m%d-%H%M%S).bak"

python3 <<'PY'
from pathlib import Path

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

agent_fn = r'''function agentPass(agent, draft, request){
  const a = String(agent || "ZAY").toUpperCase();
  const base = cleanAgentText(draft || "");
  const dna = global.MUSIC_ENGINE && global.MUSIC_ENGINE.dna ? global.MUSIC_ENGINE.dna : {};
  const weights = dna.weights || { cadence:.8, emotion:.8, structure:.8, imagery:.8 };
  const terms = (dna.styleTerms || []).join(", ");

  if (a === "ZAY") {
    return `[ZAY — CADENCE / BOUNCE]

${base}

Agent move: tighten rhythm, shorten heavy phrasing, and make the last phrase hit in-pocket.
DNA influence: cadence ${weights.cadence} · style terms ${terms}`;
  }

  if (a === "RIYA") {
    return `[RIYA — EMOTION / IMAGERY]

${base}

Agent move: make the emotional image more specific while keeping the artist voice plain-spoken.
DNA influence: emotion ${weights.emotion} · imagery ${weights.imagery}`;
  }

  if (a === "DJ") {
    return `[DJ — STRUCTURE / HOOK]

${base}

Agent move: move the strongest repeatable phrase into hook position and clean the transition.
DNA influence: structure ${weights.structure}`;
  }

  return base;
}
'''

start = text.find("function agentPass(agent, draft, request)")
if start == -1:
    raise SystemExit("Could not find agentPass")

# Find next function/app route after agentPass
candidates = [
    text.find("\nfunction ", start + 1),
    text.find("\napp.", start + 1),
    text.find("\n// =====", start + 1)
]
candidates = [x for x in candidates if x != -1]
if not candidates:
    raise SystemExit("Could not find end of agentPass")

end = min(candidates)
text = text[:start] + agent_fn + "\n" + text[end:]

p.write_text(text, encoding="utf-8")
print("agentPass repaired safely")
PY

node -c server.js

git add server.js
git commit -m "Fix agentPass multiline strings" || true
git push origin main
fly deploy --local-only

echo "Testing chain..."
curl -s -X POST https://tsm-shell.fly.dev/api/music/agent/chain \
  -H "Content-Type: application/json" \
  -d '{"draft":"Life surrounded by wrong but trying to stay right is a fight\nEvery day a battle every night a new light","request":"full chain"}'
echo
