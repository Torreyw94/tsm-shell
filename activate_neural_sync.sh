#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

FILE="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/neural_sync
cp -f "$FILE" "backups/neural_sync/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("/workspaces/tsm-shell/html/honor-portal/index.html")
text = p.read_text(encoding="utf-8", errors="ignore")

def inject_before_body(block: str):
    global text
    if block in text:
        return
    if "</body>" in text:
        text = text.replace("</body>", block + "\n</body>", 1)
    else:
        text += "\n" + block

# Mark KPI nodes if not already marked
repls = [
    ('>$266,830<', ' data-kpi="risk">$266,830<'),
    ('>$90,722<', ' data-kpi="72h">$90,722<'),
    ('>$127,011<', ' data-kpi="14d">$127,011<'),
    ('>Billing<', ' data-kpi="lane">Billing<'),
]
for a,b in repls:
    if a in text:
        text = text.replace(a,b,1)

sync_block = r"""
<script>
window.NEURAL_SYNC = {
  system: 'HonorHealth',
  location: 'Scottsdale - Shea',
  audience: 'cfo',

  money(v){
    const n = Number(v || 0);
    return '$' + n.toLocaleString();
  },

  async post(url, body){
    const res = await fetch(url, {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify(body)
    });

    const raw = await res.text();

    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    if (raw.startsWith('<!DOCTYPE') || raw.startsWith('<html')) {
      throw new Error(`HTML fallback from ${url}`);
    }

    return JSON.parse(raw);
  },

  async getBrief(question){
    return this.post('/api/hc/brief', {
      system: this.system,
      location: this.location,
      audience: this.audience,
      format: 'email',
      question: question || 'What is driving current revenue pressure and what are we doing about it?'
    });
  },

  async getRollup(){
    return this.post('/api/hc/rollup', {
      system: this.system,
      top_n: 3
    });
  },

  async getAlerts(){
    return this.post('/api/hc/alerts', {
      system: this.system
    });
  },

  findExecTarget(){
    const direct = document.querySelector('[data-email="brief"]');
    if (direct) return direct;

    const nodes = Array.from(document.querySelectorAll('div, p, section'));
    const execLabel = nodes.find(n => /EXECUTIVE CORRESPONDENCE/i.test(n.textContent || ''));
    if (!execLabel) return null;

    let container = execLabel.parentElement;
    for (let i = 0; i < 3 && container; i++) {
      const candidate = Array.from(container.querySelectorAll('div, p')).find(el => (el.textContent || '').includes('Subject:'));
      if (candidate) return candidate;
      container = container.parentElement;
    }

    const out = document.createElement('div');
    out.setAttribute('data-email','brief');
    execLabel.parentElement.appendChild(out);
    return out;
  },

  findAlertsTarget(){
    const nodes = Array.from(document.querySelectorAll('div, section'));
    return nodes.find(n => /ACTIVE ALERTS/i.test(n.textContent || ''));
  },

  setLoading(msg){
    const tgt = this.findExecTarget();
    if (tgt) {
      tgt.innerHTML = '<div style="white-space:pre-wrap;line-height:1.7;opacity:.8">⏳ ' + msg + '</div>';
    }
  },

  updateKPIs(brief){
    const risk = document.querySelector('[data-kpi="risk"]');
    const r72 = document.querySelector('[data-kpi="72h"]');
    const d14 = document.querySelector('[data-kpi="14d"]');
    const lane = document.querySelector('[data-kpi="lane"]');

    if (risk && brief.revenueAtRisk != null) risk.textContent = this.money(brief.revenueAtRisk);
    if (r72 && brief.recoverable72h != null) r72.textContent = this.money(brief.recoverable72h);
    if (d14 && brief.cashAcceleration14d != null) d14.textContent = this.money(brief.cashAcceleration14d);
    if (lane && brief.highestYieldLane) lane.textContent = brief.highestYieldLane;
  },

  updateBrief(brief){
    const tgt = this.findExecTarget();
    if (!tgt) return;
    tgt.innerHTML = '<div style="white-space:pre-wrap;line-height:1.72;">' + (brief.brief || 'No brief returned.') + '</div>';
  },

  updateAlerts(alerts){
    const root = this.findAlertsTarget();
    if (!root || !alerts || !Array.isArray(alerts.alerts)) return;

    let host = root.parentElement || root;
    let box = document.getElementById('neural-alert-box');
    if (!box) {
      box = document.createElement('div');
      box.id = 'neural-alert-box';
      box.style.cssText = 'margin-top:10px;padding-top:10px;border-top:1px solid rgba(255,255,255,.08);display:grid;gap:8px;';
      host.appendChild(box);
    }

    box.innerHTML = alerts.alerts.map(a => `
      <div style="display:flex;justify-content:space-between;gap:12px;padding:8px 10px;border:1px solid rgba(255,255,255,.06);border-radius:8px;background:rgba(255,255,255,.03);">
        <div><b>${a.severity}</b> · ${a.message}</div>
        <div style="opacity:.75">${a.type}</div>
      </div>
    `).join('');
  },

  async refresh(question){
    this.setLoading('Pulling HonorHealth HC-only analysis...');
    const [brief, rollup, alerts] = await Promise.all([
      this.getBrief(question),
      this.getRollup(),
      this.getAlerts()
    ]);

    this.updateKPIs(brief);
    this.updateBrief(brief);
    this.updateAlerts(alerts);

    const updated = document.getElementById('neural-last-updated');
    if (updated) {
      updated.textContent = 'Last sync: ' + new Date().toLocaleTimeString();
    }

    return { brief, rollup, alerts };
  }
};
</script>
"""

inject_before_body(sync_block)

ui_block = r"""
<script>
(function wireNeuralSyncUI(){
  function ensureStatus(){
    if (document.getElementById('neural-last-updated')) return;
    const lock = Array.from(document.querySelectorAll('div')).find(d => (d.textContent || '').includes('Cross-sector bleed: OFF'));
    if (lock) {
      const meta = document.createElement('div');
      meta.id = 'neural-last-updated';
      meta.style.cssText = 'margin-top:8px;font-size:12px;opacity:.8;';
      meta.textContent = 'Last sync: waiting...';
      lock.parentElement.appendChild(meta);
    }
  }

  async function run(question){
    try {
      await window.NEURAL_SYNC.refresh(question);
    } catch (e) {
      console.warn('Neural sync failed:', e.message);
      const tgt = window.NEURAL_SYNC.findExecTarget();
      if (tgt) {
        tgt.innerHTML = '<div style="white-space:pre-wrap;line-height:1.7;color:#ffb3b3">Neural sync failed: ' + e.message + '</div>';
      }
    }
  }

  ensureStatus();

  const buttons = Array.from(document.querySelectorAll('button'));

  const cfo = buttons.find(b => /Generate CFO Email/i.test(b.textContent || ''));
  if (cfo && !cfo.dataset.ns) {
    cfo.dataset.ns = '1';
    cfo.addEventListener('click', () => run(window.HONOR_PACKS?.executive || 'Generate an executive brief for HonorHealth revenue cycle leadership.'));
  }

  const refresh = buttons.find(b => /Refresh Live Intelligence/i.test(b.textContent || ''));
  if (refresh && !refresh.dataset.ns) {
    refresh.dataset.ns = '1';
    refresh.addEventListener('click', () => run(window.HONOR_QUICK?.priority || 'What is the single highest-priority action Dee Montee should take right now?'));
  }

  const copy = buttons.find(b => /Copy Brief/i.test(b.textContent || ''));
  if (copy && !copy.dataset.ns) {
    copy.dataset.ns = '1';
    copy.addEventListener('click', async () => {
      const tgt = window.NEURAL_SYNC.findExecTarget();
      if (tgt) await navigator.clipboard.writeText(tgt.textContent || '');
    });
  }

  // Upgrade quickAsk to use neural sync path
  window.quickAsk = async function(prompt){
    await run(prompt);
  };

  // Auto-sync once on load
  setTimeout(() => {
    run('What is driving current revenue pressure and what are we doing about it?');
  }, 450);
})();
</script>
"""

inject_before_body(ui_block)

p.write_text(text, encoding="utf-8")
print("activated neural sync in honor portal")
PY

echo "== VERIFY =="
grep -n "window.NEURAL_SYNC\|wireNeuralSyncUI\|neural-last-updated\|data-kpi=" "$FILE" || true

echo "== COMMIT =="
git add "$FILE"
git commit -m "Activate neural sync in honor portal" || true

echo "== PUSH =="
git stash -u || true
git pull --rebase origin main || true
git push origin main || true
git stash pop || true

echo "== DEPLOY =="
fly deploy
