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

auto_sync_script = """
// ================= AUTO SYNC NODES =================

let AUTO_SYNC_INTERVAL = null;

function startAutoSync(intervalMs = 10000) {
  if (AUTO_SYNC_INTERVAL) clearInterval(AUTO_SYNC_INTERVAL);

  AUTO_SYNC_INTERVAL = setInterval(async () => {
    try {
      const system =
        document.getElementById('system-filter')?.value ||
        'HonorHealth';

      const location =
        document.getElementById('location-filter')?.value ||
        'Scottsdale - Shea';

      const res = await fetch(
        `/api/hc/nodes/filter?system=${encodeURIComponent(system)}&location=${encodeURIComponent(location)}`
      );

      const data = await res.json();
      if (!data.ok) return;

      updateNodeUI(data.state);

      // OPTIONAL: auto-run Layer 2 quietly
      autoRunLayer2(system, location);

    } catch (e) {
      console.warn('Auto-sync failed', e);
    }
  }, intervalMs);
}

function stopAutoSync() {
  if (AUTO_SYNC_INTERVAL) {
    clearInterval(AUTO_SYNC_INTERVAL);
    AUTO_SYNC_INTERVAL = null;
  }
}

function autoRunLayer2(system, location) {
  fetch('/api/hc/layer2', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ system, location })
  })
  .then(r => r.json())
  .then(data => {
    if (!data.ok) return;

    const el = document.getElementById('layer2-live');
    if (el) {
      el.innerHTML = data.output.replace(/\\n/g, '<br>');
    }
  })
  .catch(()=>{});
}

// Update node cards (simple version)
function updateNodeUI(state) {
  Object.entries(state || {}).forEach(([key, node]) => {
    const el = document.querySelector(`[data-node="${key}"]`);
    if (!el) return;

    el.classList.add('live');
    el.setAttribute('title', node.findings || 'Live');

    // optional: inject mini metrics
    if (node.queueDepth !== undefined) {
      el.innerText = `${key.toUpperCase()}\\nQ:${node.queueDepth}`;
    }
  });
}

// Auto-start on load
window.addEventListener('load', () => {
  startAutoSync(10000); // every 10s
});
"""

# Inject script if not present
if "AUTO SYNC NODES" not in text:
    if "</script>" in text:
        text = text.replace("</script>", auto_sync_script + "\n</script>", 1)
    else:
        text += "\n<script>\n" + auto_sync_script + "\n</script>\n"

# Add a small live panel if not present
live_panel = """
<div id="layer2-live" class="ai-res" style="margin-top:10px;">
> Live BNCA will stream here...
</div>
"""

if "layer2-live" not in text:
    text = text.replace("RUN ENTERPRISE BNCA", "RUN ENTERPRISE BNCA</button>" + live_panel)

p.write_text(text, encoding="utf-8")
print("patched auto-sync into strategist UI")
PY

echo "== COMMIT =="
git add "$UI"
git commit -m "Add auto-sync nodes + live BNCA stream" || true

echo "== PUSH =="
git push origin main

echo "== DEPLOY =="
fly deploy

echo
echo "Open:"
echo "https://tsm-shell.fly.dev/html/hc-strategist/"
echo
echo "Auto-sync will start automatically."
