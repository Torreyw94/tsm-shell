#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
cp server.js "backups/server.js.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8")

# Find a generic frontend fallback block and remove it.
patterns = [
    r"""app\.use\(\(req,\s*res(?:,\s*next)?\)\s*=>\s*\{\s*if\s*\(req\.path\.startsWith\('/api/'\)\)\s*\{\s*return\s+res\.status\(404\)\.json\(\{\s*ok:false,\s*error:\s*'API route not found'\s*\}\);\s*\}\s*return\s+res\.sendFile\(path\.join\(__dirname,\s*'html',\s*'index\.html'\)\);\s*\}\);""",
    r"""app\.use\(\(req,\s*res(?:,\s*next)?\)\s*=>\s*\{\s*res\.sendFile\(path\.join\(__dirname,\s*'html',\s*'index\.html'\)\);\s*\}\);""",
    r"""app\.use\(\(req,\s*res(?:,\s*next)?\)\s*=>\s*\{\s*res\.sendFile\(path\.join\(__dirname,\s*req\.path\)[\s\S]*?\}\);""",
]
for pat in patterns:
    text = re.sub(pat, "", text, flags=re.S)

# Append ONE safe fallback at the very end.
fallback = """

// ===== FRONTEND FALLBACK (KEEP LAST) =====
app.use((req, res) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ ok: false, error: 'API route not found' });
  }

  // serve exact frontend file/path when present, otherwise launcher
  return res.sendFile(path.join(__dirname, req.path), (err) => {
    if (err) {
      return res.sendFile(path.join(__dirname, 'html', 'index.html'));
    }
  });
});
"""

text = text.rstrip() + "\n" + fallback + "\n"
p.write_text(text, encoding="utf-8")
print("patched server.js")
PY

node -c server.js

echo "== CHECK ORDER =="
grep -n "/api/hc/rollup/brief\|/api/hc/alerts\|FRONTEND FALLBACK" server.js

git add server.js
git commit -m "Move frontend fallback below API routes" || true
git push origin main
fly deploy
