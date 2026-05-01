#!/usr/bin/env bash
set -e

FILE="/workspaces/tsm-shell/html/honor-portal/index.html"
cp "$FILE" "$FILE.realactions.$(date +%s).bak"

python3 <<'PY'
from pathlib import Path

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

# Replace placeholder logic with real API call
text = text.replace(
"if(action === 'brief'){",
"""
if(action === 'brief'){
  runDeeAction('Generate a full team briefing for HonorHealth revenue cycle');
"""
)

text = text.replace(
"if(action === 'recovery'){",
"""
if(action === 'recovery'){
  runDeeAction('Run denial recovery strategy for Scottsdale - Shea');
"""
)

# Inject real Dee action function
if "function runDeeAction" not in text:
    inject = """
<script>

async function runDeeAction(prompt){
  const out = document.getElementById('dee-live-inner');
  if(!out) return;

  out.innerHTML = '<div class="dee-narrative">Running AI...</div>';

  try{
    const res = await fetch('/api/strategist/hc/dee-action', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        system:'HonorHealth',
        selectedOffice:'Scottsdale - Shea',
        prompt: prompt
      })
    });

    const data = await res.json();

    out.innerHTML = '<pre style="white-space:pre-wrap">' + JSON.stringify(data, null, 2) + '</pre>';

  } catch(e){
    out.innerHTML = '<div class="dee-alert">AI request failed</div>';
  }
}

</script>
"""
    text = text.replace("</body>", inject + "\n</body>")

p.write_text(text, encoding="utf-8")
print("Real Dee actions wired")
PY

git add "$FILE"
git commit -m "Wire real strategist into Dee actions" || true
git push || true
fly deploy
