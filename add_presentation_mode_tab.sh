#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

UI="html/hc-strategist/index.html"
BACKUP_DIR="backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$UI" ] || { echo "Missing $UI"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$UI" "$BACKUP_DIR/hc-strategist.index.html.$STAMP.bak"

python3 <<'PY'
from pathlib import Path

p = Path("html/hc-strategist/index.html")
text = p.read_text(encoding="utf-8")

nav_button = """
<button class="nav-btn" onclick="switchTab('presentation', this)">🎤 PRESENTATION MODE</button>
"""

presentation_tab = r"""
<div id="tab-presentation">
  <div class="ai-box" style="margin-top:16px">
    <div class="ai-hdr">🎤 THURSDAY PRESENTATION MODE</div>
    <div class="ai-row" style="margin-bottom:10px;">
      <button class="ai-btn" onclick="copyPresentationScript()">COPY TALK TRACK</button>
    </div>
    <div id="presentation-script" class="ai-res" style="white-space:pre-wrap; line-height:1.7;">OPEN

“What you’re looking at is not a dashboard — it’s a live operational intelligence system.”

“It tells your office what to do next — and how much money is at risk if you don’t.”

STEP 1 — SET CONTEXT

“Every healthcare system is dealing with the same three pressures:
• claim delays
• prior auth friction
• operational bottlenecks at the front desk

The problem is — those don’t live in one system. They compound across teams.”

STEP 2 — SHOW THE SYSTEM

Navigate to /html/healthcare/

“This is your live operational surface — every node represents a functional lane:
operations, billing, insurance, compliance.

Each one is reporting pressure in real time.”

STEP 3 — TRANSITION TO STRATEGIST

Move to /html/hc-strategist/

“But this is where it becomes actionable.”

STEP 4 — CLICK THE BUTTON

Click RUN ENTERPRISE BNCA

[Pause 2–3 seconds]

STEP 5 — READ THE OUTPUT

“Right now, the system is identifying $266,000 at risk.”

[Pause]

“It’s showing $90,000 recoverable in 72 hours…”

[Pause]

“…and $127,000 in 14-day cash acceleration.”

“And it’s telling us the highest-yield lane is Billing.”

STEP 6 — EXPLAIN ROOT CAUSE

“But this isn’t just billing.

This is the important part — it’s showing:
• denial pressure
• auth backlog
• intake bottlenecks

That’s why revenue is stuck — it’s cross-functional.”

STEP 7 — ACTION

“Now instead of guessing, your team knows exactly what to do next:
• clear high-value backlog
• escalate auth delays
• rebalance intake and scheduling”

STEP 8 — DIFFERENTIATION

“Most systems show you data.

This tells your office what to do — in priority order — tied to real dollars.”

STEP 9 — CLOSE

“If we deployed this in your environment…

…we’d be identifying and acting on revenue leakage within the first 48 hours.”

OPTIONAL HARD CLOSE

“The question isn’t whether this works.

It’s how quickly you want this running inside your system.”

OBJECTION HANDLING

If they say: “We already have dashboards”
Say: “This sits on top — it translates your data into action and financial impact.”

If they say: “Is this real data?”
Say: “Right now this is a live simulation — in your environment this would be pulling directly from your systems.”

If they say: “Who uses this?”
Say: “Office managers, revenue cycle leaders, and operations — the people who actually fix the problems.”

FINAL LINE

“We’re not replacing your systems — we’re making them actionable.”</div>
  </div>
</div>
"""

script_block = """
function copyPresentationScript() {
  const el = document.getElementById('presentation-script');
  if (!el) return;
  navigator.clipboard.writeText(el.innerText || el.textContent || '').then(() => {
    const prev = el.innerHTML;
    el.innerHTML = '<b>Copied presentation script to clipboard.</b>\\n\\n' + prev;
    setTimeout(() => { el.innerHTML = prev; }, 1200);
  }).catch(() => {});
}
"""

# 1) Add nav button once
if "PRESENTATION MODE" not in text:
    marker = "</div></div><div id=\"tab-ai\">"
    if marker in text:
        text = text.replace(marker, nav_button + marker, 1)
    else:
        nav_marker = "RUN ENTERPRISE BNCA"
        idx = text.find(nav_marker)
        if idx != -1:
            text = text[:idx] + nav_button + text[idx:]

# 2) Add presentation tab once
if 'id="tab-presentation"' not in text:
    if "</body>" in text:
        text = text.replace("</body>", presentation_tab + "\n</body>", 1)
    else:
        text += "\n" + presentation_tab

# 3) Add helper function once
if "function copyPresentationScript()" not in text:
    if "</script>" in text:
        text = text.replace("</script>", script_block + "\n</script>", 1)
    else:
        text += "\n<script>\n" + script_block + "\n</script>\n"

p.write_text(text, encoding="utf-8")
print("patched html/hc-strategist/index.html")
PY

git add "$UI"
git commit -m "Add presentation mode tab to strategist" || true
git push origin main
fly deploy

echo
echo "Open:"
echo "https://tsm-shell.fly.dev/html/hc-strategist/"
echo
echo "Click:"
echo "PRESENTATION MODE"
