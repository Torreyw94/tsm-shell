#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

LIVE="html/honor-portal/index.html"
BRAIN="html/honor-portal/nu-dee-portal.html"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$LIVE" ] || { echo "Missing $LIVE"; exit 1; }
[ -f "$BRAIN" ] || { echo "Missing $BRAIN"; exit 1; }

mkdir -p backups/merge_dee_brain
cp -f "$LIVE" "backups/merge_dee_brain/index.before.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

live_path = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
brain_path = Path("/workspaces/tsm-shell/html/honor-portal/nu-dee-portal.html")

live = live_path.read_text(encoding="utf-8", errors="ignore")
brain = brain_path.read_text(encoding="utf-8", errors="ignore")

def inject_before_body(html, block):
    if not block or block in html:
        return html
    if "</body>" in html:
        return html.replace("</body>", block + "\n</body>", 1)
    return html + "\n" + block

# 1) Ensure neural marker exists
banner = """<div class="cm ca">◈ HC Strategist online — HonorHealth profile locked. Cross-sector bleed: OFF. Ask me about denials, auths, offices, appeals, or revenue.</div>"""
if "Cross-sector bleed: OFF" not in live:
    live = inject_before_body(live, banner)

# 2) Pull all quickAsk() button lines from nu-dee and build a compact action rail
brain_buttons = re.findall(r'<button class="btn btn-strat"[^>]*onclick="quickAsk\([^\n]+?</button>', brain)
# Deduplicate while preserving order
seen = set()
deduped = []
for b in brain_buttons:
    key = re.sub(r'\s+', ' ', b.strip())
    if key not in seen:
        seen.add(key)
        deduped.append(b)

top_actions = []
strategy_rows = []
for b in deduped:
    if "Strategy →" in b or "◈ Strategy" in b:
        strategy_rows.append(b)
    else:
        top_actions.append(b)

top_actions = top_actions[:8]
strategy_rows = strategy_rows[:8]

action_panel = ""
if top_actions:
    action_panel = """
<div id="dee-brain-actions" style="margin:18px 0;padding:14px;border:1px solid rgba(255,255,255,.08);border-radius:12px;background:rgba(10,18,34,.72);">
  <div style="font-size:12px;letter-spacing:.12em;color:#8fb3ff;text-transform:uppercase;margin-bottom:10px;">Dee Neural Actions</div>
  <div style="display:flex;flex-wrap:wrap;gap:8px;">
    %s
  </div>
</div>
""" % ("\n".join(top_actions))

if 'id="dee-brain-actions"' not in live:
    # Insert after top KPI region if possible, else before body end
    if "LIVE OFFICE STATE" in live:
        live = live.replace("LIVE OFFICE STATE", action_panel + "\nLIVE OFFICE STATE", 1)
    else:
        live = inject_before_body(live, action_panel)

# 3) Add payer / denial strategy table from nu-dee if absent
if strategy_rows and 'id="dee-payer-strategies"' not in live:
    strategy_panel = """
<div id="dee-payer-strategies" style="margin:18px 0;padding:14px;border:1px solid rgba(255,255,255,.08);border-radius:12px;background:rgba(10,18,34,.72);">
  <div style="font-size:12px;letter-spacing:.12em;color:#8fb3ff;text-transform:uppercase;margin-bottom:10px;">Payer / Denial Strategy</div>
  <div style="display:grid;gap:8px;">
    %s
  </div>
</div>
""" % ("\n".join(f'<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;">{row}</div>' for row in strategy_rows))
    if "EXECUTIVE CORRESPONDENCE" in live:
        live = live.replace("EXECUTIVE CORRESPONDENCE", strategy_panel + "\nEXECUTIVE CORRESPONDENCE", 1)
    else:
        live = inject_before_body(live, strategy_panel)

# 4) Strengthen quickAsk() to visibly update the correspondence panel and show loading
qa_match = re.search(r'async function quickAsk\(prompt\)\s*\{[\s\S]*?\n\}', live)
new_quickask = """
async function quickAsk(prompt){
  try{
    const panel = document.querySelector('[data-email="brief"]')?.parentElement?.parentElement
      || Array.from(document.querySelectorAll('div')).find(d => (d.textContent || '').includes('EXECUTIVE CORRESPONDENCE'))
      || document.body;

    let target = Array.from(panel.querySelectorAll('div, p')).find(el => (el.textContent || '').includes('Subject:'));
    if(!target){
      target = document.createElement('div');
      panel.appendChild(target);
    }

    target.innerHTML = '<div style="white-space:pre-wrap;line-height:1.7;opacity:.75">⏳ Pulling HonorHealth HC-only analysis...\\n\\n' + prompt + '</div>';

    const res = await fetch('/api/hc/brief', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({
        system: 'HonorHealth',
        location: 'Scottsdale - Shea',
        audience: 'cfo',
        format: 'email',
        question: prompt
      })
    });

    const text = await res.text();
    if (text.startsWith('<!DOCTYPE') || text.startsWith('<html')) {
      throw new Error('HTML fallback returned instead of JSON');
    }

    const data = JSON.parse(text);
    if(!data || (!data.brief && !data.error)) throw new Error('No brief returned');

    const body = data.brief || data.error || 'No response';
    target.innerHTML = '<div style="white-space:pre-wrap;line-height:1.7;">' + body + '</div>';

    const risk = document.querySelector('[data-kpi="risk"]');
    const rec72 = document.querySelector('[data-kpi="72h"]');
    const acc14 = document.querySelector('[data-kpi="14d"]');
    const lane = document.querySelector('[data-kpi="lane"]');
    if (risk && data.revenueAtRisk != null) risk.textContent = '$' + Number(data.revenueAtRisk).toLocaleString();
    if (rec72 && data.recoverable72h != null) rec72.textContent = '$' + Number(data.recoverable72h).toLocaleString();
    if (acc14 && data.cashAcceleration14d != null) acc14.textContent = '$' + Number(data.cashAcceleration14d).toLocaleString();
    if (lane && data.highestYieldLane) lane.textContent = data.highestYieldLane;

  }catch(e){
    console.warn('quickAsk failed:', e.message);
  }
}
"""
if qa_match:
    live = live[:qa_match.start()] + new_quickask + live[qa_match.end():]
else:
    live = inject_before_body(live, f"<script>\n{new_quickask}\n</script>")

# 5) Mark KPI targets if not already marked
live = live.replace('>$266,830<', ' data-kpi="risk">$266,830<', 1)
live = live.replace('>$90,722<', ' data-kpi="72h">$90,722<', 1)
live = live.replace('>$127,011<', ' data-kpi="14d">$127,011<', 1)
live = live.replace('>Billing<', ' data-kpi="lane">Billing<', 1)

# 6) Wire top buttons to neural asks if not already strong
wiring = """
<script>
(function wireDeeTopButtons(){
  const buttons = Array.from(document.querySelectorAll('button'));
  const cfo = buttons.find(b => /Generate CFO Email/i.test(b.textContent || ''));
  const refresh = buttons.find(b => /Refresh Live Intelligence/i.test(b.textContent || ''));
  const copy = buttons.find(b => /Copy Brief/i.test(b.textContent || ''));

  if (cfo && !cfo.dataset.deeWired) {
    cfo.dataset.deeWired = '1';
    cfo.addEventListener('click', () => quickAsk(window.HONOR_PACKS?.executive || 'Generate an executive brief for HonorHealth revenue cycle leadership.'));
  }
  if (refresh && !refresh.dataset.deeWired) {
    refresh.dataset.deeWired = '1';
    refresh.addEventListener('click', () => quickAsk(window.HONOR_QUICK?.priority || 'What is the single highest-priority action Dee Montee should take right now?'));
  }
  if (copy && !copy.dataset.deeWired) {
    copy.dataset.deeWired = '1';
    copy.addEventListener('click', async () => {
      const panel = Array.from(document.querySelectorAll('div, p')).find(el => (el.textContent || '').includes('Subject: Scottsdale - Shea Revenue Pressure Update'));
      if (panel) await navigator.clipboard.writeText(panel.textContent || '');
    });
  }
})();
</script>
"""
live = inject_before_body(live, wiring)

live_path.write_text(live, encoding="utf-8")
print("merged nu-dee brain into live honor portal")
PY

echo "== VERIFY =="
grep -n 'dee-brain-actions\|dee-payer-strategies\|Cross-sector bleed: OFF\|HONOR_PACKS\|HONOR_QUICK\|async function quickAsk' "$LIVE" || true

echo "== COMMIT =="
git add "$LIVE"
git commit -m "Merge Dee brain into live honor portal" || true

echo "== PUSH =="
git pull --rebase origin main || true
git push origin main || true

echo "== DEPLOY =="
fly deploy
