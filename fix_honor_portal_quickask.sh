#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

FILE="html/honor-portal/index.html"
cp -f "$FILE" "$FILE.quickaskbak.$(date +%s)"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

bridge = """
<script>
if (typeof window.quickAsk !== 'function') {
  window.quickAsk = async function(promptText) {
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
        <div style="margin-top:16px;padding:16px;border:1px solid rgba(0,255,163,.18);background:#07111b;color:#00ffa3;font-family:monospace;">
          <div style="font-size:16px;font-weight:700;margin-bottom:10px;">TSM Strategist Response</div>
          <div style="white-space:pre-wrap;font-size:12px;line-height:1.55;">${
            (data && data.actionBoard && (
              "TOP PRIORITY\\n" + (data.actionBoard.topPriorityNow || "—") + "\\n\\n" +
              "PAYER FOCUS\\n" + (data.actionBoard.payerFocus || "—") + "\\n\\n" +
              "NARRATIVE\\n" + (data.actionBoard.strategistNarrative || "—") + "\\n\\n" +
              "ACTIONS\\n- " + ((data.actionBoard.actions || []).join("\\n- ") || "—")
            )) || JSON.stringify(data, null, 2)
          }</div>
        </div>
      `;

      if (target.id === 'dee-content') {
        target.innerHTML = html;
      } else {
        target.insertAdjacentHTML('beforeend', html);
      }

      return data;
    } catch (e) {
      console.error('quickAsk bridge failed', e);
      return { ok:false, error:e.message };
    }
  };
}
</script>
"""

if "window.quickAsk = async function" not in text:
    text = text.replace("</body>", bridge + "\n</body>")

p.write_text(text, encoding="utf-8")
print("quickAsk bridge injected")
PY

git add "$FILE"
git commit -m "Add quickAsk bridge to honor portal" || true
git pull --rebase origin main || true
git push origin main || true
fly deploy
