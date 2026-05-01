#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.globalfix.$(date +%s)"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# 1. REMOVE existing quickAsk scripts (avoid duplicates)
import re
text = re.sub(r'<script>.*?quickAsk.*?</script>', '', text, flags=re.S)

# 2. INSERT AT VERY TOP (before any UI loads)
inject = """
<script>
// ===== FORCE GLOBAL QUICKASK (LOAD FIRST) =====
window.quickAsk = async function(promptText){
  try {
    const r = await fetch('/api/strategist/hc/dee-action', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({
        system: 'HonorHealth',
        selectedOffice: 'Scottsdale - Shea',
        prompt: promptText || ''
      })
    });

    const data = await r.json();

    const target =
      document.getElementById('dee-content') ||
      document.getElementById('dee-command-center') ||
      document.body;

    const html = `
      <div style="margin-top:16px;padding:16px;border:1px solid rgba(0,255,163,.2);background:#07111b;color:#00ffa3;font-family:monospace;">
        <b>TSM Strategist Response</b><br><br>
        <pre style="white-space:pre-wrap;font-size:12px;">
${JSON.stringify(data, null, 2)}
        </pre>
      </div>
    `;

    if(target) target.insertAdjacentHTML('beforeend', html);

    return data;

  } catch(e){
    console.error('quickAsk failed', e);
  }
};
</script>
"""

# inject right after <head>
text = text.replace("<head>", "<head>\n" + inject)

p.write_text(text, encoding="utf-8")
print("✅ quickAsk forced global load")
PY

git add "$FILE"
git commit -m "Force global quickAsk load order" || true
git push origin main || true
fly deploy
