#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_tier_paywall

cp -f server.js "backups/music_tier_paywall/server.$STAMP.bak"
cp -f html/music-command/index.html "backups/music_tier_paywall/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_tier_paywall/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("server.js")
text = p.read_text(encoding="utf-8", errors="ignore")

block = r'''
// ===== MUSIC TIER + PAYWALL + USAGE LAYER =====
global.MUSIC_BILLING = global.MUSIC_BILLING || {
  currentTier: "free",
  usage: {
    aiRuns: 0,
    exports: 0,
    hookPacks: 0,
    sessions: 0
  },
  tiers: {
    free: {
      name:"Free Trial",
      price:0,
      aiRuns:5,
      sessions:1,
      exports:false,
      dna:"Preview only",
      label:"Test the system. See how it thinks.",
      bestFor:"Trying the engine before committing."
    },
    tier1: {
      name:"Creator Mode",
      price:99,
      aiRuns:25,
      sessions:5,
      exports:true,
      dna:"Basic Artist DNA",
      label:"Turn rough ideas into structured, polished drafts fast.",
      bestFor:"Independent artists writing consistently."
    },
    tier2: {
      name:"Studio Mode",
      price:249,
      aiRuns:100,
      sessions:25,
      exports:true,
      dna:"Advanced Artist DNA + evolution timeline",
      label:"Know which version is actually better. Stop guessing what works.",
      bestFor:"Artists serious about releasing music."
    },
    tier3: {
      name:"Label Mode",
      price:499,
      aiRuns:500,
      sessions:100,
      exports:true,
      dna:"Deep catalog memory + release decision engine",
      label:"Build a catalog. Not just songs. Operate like a label.",
      bestFor:"Teams, producers, and catalog builders."
    }
  },
  upgradeEvents: []
};

function musicTier(){
  return global.MUSIC_BILLING.tiers[global.MUSIC_BILLING.currentTier] || global.MUSIC_BILLING.tiers.free;
}

function musicCanUse(kind){
  const tier = musicTier();
  const usage = global.MUSIC_BILLING.usage;

  if(kind === "aiRuns" && usage.aiRuns >= tier.aiRuns){
    return { ok:false, reason:"AI run limit reached", upgrade:true, tier };
  }

  if(kind === "sessions" && usage.sessions >= tier.sessions){
    return { ok:false, reason:"Session limit reached", upgrade:true, tier };
  }

  if(kind === "exports" && !tier.exports){
    return { ok:false, reason:"Exports require Creator Mode", upgrade:true, tier };
  }

  return { ok:true, tier };
}

app.get('/api/music/billing/state', (_req, res) => {
  const tier = musicTier();
  return res.json({
    ok:true,
    billing:global.MUSIC_BILLING,
    current:tier,
    remaining:{
      aiRuns:Math.max(0, tier.aiRuns - global.MUSIC_BILLING.usage.aiRuns),
      sessions:Math.max(0, tier.sessions - global.MUSIC_BILLING.usage.sessions),
      exports:tier.exports
    }
  });
});

app.post('/api/music/billing/upgrade-intent', (req, res) => {
  const body = req.body || {};
  const targetTier = body.tier || "tier1";

  if(!global.MUSIC_BILLING.tiers[targetTier]){
    return res.status(400).json({ ok:false, error:"Invalid tier" });
  }

  const event = {
    id:Date.now(),
    from:global.MUSIC_BILLING.currentTier,
    to:targetTier,
    reason:body.reason || "manual upgrade intent",
    createdAt:new Date().toISOString(),
    stripeReady:true
  };

  global.MUSIC_BILLING.upgradeEvents.unshift(event);

  return res.json({
    ok:true,
    upgrade:event,
    checkout:{
      provider:"stripe-ready",
      tier:targetTier,
      price:global.MUSIC_BILLING.tiers[targetTier].price,
      note:"Connect Stripe checkout URL here."
    }
  });
});

app.post('/api/music/billing/set-tier-dev', (req, res) => {
  const body = req.body || {};
  const tier = body.tier || "free";

  if(!global.MUSIC_BILLING.tiers[tier]){
    return res.status(400).json({ ok:false, error:"Invalid tier" });
  }

  global.MUSIC_BILLING.currentTier = tier;
  return res.json({ ok:true, billing:global.MUSIC_BILLING });
});
// ===== END MUSIC TIER + PAYWALL + USAGE LAYER =====
'''

text = re.sub(
  r'\n// ===== MUSIC TIER \+ PAYWALL \+ USAGE LAYER =====.*?// ===== END MUSIC TIER \+ PAYWALL \+ USAGE LAYER =====\s*',
  '\n',
  text,
  flags=re.S
)

idx = text.find("app.use((req, res) => {")
if idx == -1:
  idx = text.find("res.status(404).json({ ok: false, error: 'API route not found' });")
if idx == -1:
  raise SystemExit("API 404 block not found")

text = text[:idx] + block + "\n" + text[idx:]

# Add usage increments into successful endpoints without hard-blocking existing flow.
text = text.replace(
  "return res.json({ ok: true, run, engine: global.MUSIC_ENGINE });",
  "global.MUSIC_BILLING && (global.MUSIC_BILLING.usage.aiRuns += 1);\n  return res.json({ ok: true, run, engine: global.MUSIC_ENGINE, billing: global.MUSIC_BILLING || null });"
)

text = text.replace(
  "return res.json({ ok:true, session });",
  "global.MUSIC_BILLING && (global.MUSIC_BILLING.usage.aiRuns += 1);\n  return res.json({ ok:true, session, billing: global.MUSIC_BILLING || null });"
)

text = text.replace(
  "return res.json({ ok:true, selected:option, rerun, product:global.MUSIC_PRODUCT, engine:global.MUSIC_ENGINE });",
  "global.MUSIC_BILLING && (global.MUSIC_BILLING.usage.aiRuns += 1);\n  return res.json({ ok:true, selected:option, rerun, product:global.MUSIC_PRODUCT, engine:global.MUSIC_ENGINE, billing: global.MUSIC_BILLING || null });"
)

text = text.replace(
  "return res.json({ ok:true, artist, session });",
  "global.MUSIC_BILLING && (global.MUSIC_BILLING.usage.sessions += 1);\n  return res.json({ ok:true, artist, session, billing: global.MUSIC_BILLING || null });"
)

text = text.replace(
  "return res.json({ ok:true, export:item });",
  "global.MUSIC_BILLING && (global.MUSIC_BILLING.usage.exports += 1);\n  return res.json({ ok:true, export:item, billing: global.MUSIC_BILLING || null });"
)

text = text.replace(
  "return res.json({\n    ok:true,\n    upsell:{ name:\"Generate 10 Hooks\", price:25 },",
  "global.MUSIC_BILLING && (global.MUSIC_BILLING.usage.hookPacks += 1);\n  return res.json({\n    ok:true,\n    upsell:{ name:\"Generate 10 Hooks\", price:25 },"
)

p.write_text(text, encoding="utf-8")
print("server billing/paywall layer inserted")
PY

python3 <<'PY'
from pathlib import Path
import re

client = r'''
<script id="tsm-music-tier-paywall-ui">
(function(){
  if(window.__TSM_MUSIC_TIER_PAYWALL_UI__) return;
  window.__TSM_MUSIC_TIER_PAYWALL_UI__ = true;

  window.musicBilling = {
    state(){
      return musicSafeFetch('/api/music/billing/state');
    },
    upgradeIntent(tier, reason){
      return musicSafeFetch('/api/music/billing/upgrade-intent', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({ tier, reason })
      });
    },
    setTierDev(tier){
      return musicSafeFetch('/api/music/billing/set-tier-dev', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({ tier })
      });
    }
  };

  function tierCard(key, t, current){
    const active = key === current;
    const border = active ? 'rgba(20,241,149,.65)' : 'rgba(255,255,255,.1)';
    const badge = active ? '<div style="font-family:var(--mono);font-size:.52rem;color:#14f195;margin-bottom:6px">CURRENT PLAN</div>' : '';

    return `
      <div style="border:1px solid ${border};border-radius:10px;padding:13px;background:rgba(255,255,255,.035);box-shadow:${active ? '0 0 24px rgba(20,241,149,.1)' : 'none'}">
        ${badge}
        <div style="font-family:var(--head);font-size:.92rem;color:var(--text)">${t.name}</div>
        <div style="font-family:var(--mono);font-size:1rem;color:#14f195;margin:5px 0">$${t.price}/mo</div>
        <div style="font-size:.72rem;color:var(--text2);line-height:1.45;margin-bottom:8px">${t.label}</div>
        <div style="font-family:var(--mono);font-size:.58rem;color:#a855f7;line-height:1.65">
          ${t.aiRuns} Full AI Iterations<br>
          ${t.sessions} Projects<br>
          ${t.exports ? 'DAW-ready exports' : 'No exports'}<br>
          ${t.dna}
        </div>
        <div style="font-size:.68rem;color:var(--text2);margin-top:8px">${t.bestFor}</div>
        ${
          active
          ? ''
          : `<button class="btn btn-purple" style="width:100%;justify-content:center;margin-top:10px" onclick="musicUpgrade('${key}')">Upgrade</button>`
        }
      </div>`;
  }

  window.musicUpgrade = async function(tier){
    const data = await musicBilling.upgradeIntent(tier, 'clicked upgrade from pricing panel');
    console.log('Upgrade Intent', data);
    alert('Upgrade intent created for ' + tier + '. Stripe checkout can be connected here.');
    return data;
  };

  window.showMusicUpgradeModal = async function(reason){
    const data = await musicBilling.state();
    const tiers = data.billing.tiers;

    let modal = document.getElementById('music-upgrade-modal');
    if(!modal){
      modal = document.createElement('div');
      modal.id = 'music-upgrade-modal';
      modal.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.72);z-index:99999;display:flex;align-items:center;justify-content:center;padding:24px;';
      document.body.appendChild(modal);
    }

    modal.innerHTML = `
      <div style="max-width:860px;width:100%;background:#050b14;border:1px solid rgba(168,85,247,.45);border-radius:14px;padding:18px;box-shadow:0 0 40px rgba(168,85,247,.18)">
        <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start">
          <div>
            <div style="font-family:var(--mono);font-size:.58rem;color:#a855f7;text-transform:uppercase;letter-spacing:.14em">Upgrade Required</div>
            <h2 style="margin:6px 0;color:var(--text);font-family:var(--head)">Unlock more iterations</h2>
            <div style="color:var(--text2);font-size:.8rem">${reason || 'You reached a plan limit.'}</div>
          </div>
          <button class="btn" onclick="document.getElementById('music-upgrade-modal').remove()">Close</button>
        </div>
        <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:14px">
          ${['tier1','tier2','tier3'].map(k => tierCard(k, tiers[k], data.billing.currentTier)).join('')}
        </div>
      </div>`;
  };

  window.renderMusicPricingPanel = async function(){
    const data = await musicBilling.state();
    let panel = document.getElementById('music-pricing-panel');

    if(!panel){
      panel = document.createElement('section');
      panel.id = 'music-pricing-panel';
      panel.style.cssText = 'margin-top:14px;padding:14px;border:1px solid rgba(168,85,247,.28);background:rgba(5,10,20,.96);border-radius:10px;';
      const target = document.getElementById('mainContent') || document.querySelector('main') || document.body;
      target.appendChild(panel);
    }

    const tiers = data.billing.tiers;

    panel.innerHTML = `
      <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start">
        <div>
          <div style="font-family:var(--mono);font-size:.58rem;color:#a855f7;text-transform:uppercase;letter-spacing:.14em">Plans Built Around Output</div>
          <h3 style="margin:5px 0;color:var(--text);font-family:var(--head)">Better songs, faster, with confidence.</h3>
          <div style="color:var(--text2);font-size:.78rem">
            Current: ${data.current.name} · ${data.remaining.aiRuns} AI iterations left
          </div>
        </div>
        <button class="btn btn-purple" onclick="showMusicUpgradeModal('Choose the plan that matches your creative volume.')">Compare Plans</button>
      </div>

      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:9px;margin-top:14px">
        ${Object.keys(tiers).map(k => tierCard(k, tiers[k], data.billing.currentTier)).join('')}
      </div>

      <div style="margin-top:12px;padding:10px;border:1px solid rgba(20,241,149,.22);border-radius:8px;background:rgba(20,241,149,.04)">
        <div style="font-family:var(--mono);font-size:.55rem;color:#14f195;text-transform:uppercase;letter-spacing:.12em">Upgrade Trigger</div>
        <div style="font-size:.76rem;color:var(--text2);margin-top:5px">
          After every revision, show the score improvement. When users hit limits, connect the value they just felt to the upgrade.
        </div>
      </div>
    `;

    console.log('Music Billing State', data);
    return data;
  };

  window.addEventListener('load', function(){
    setTimeout(renderMusicPricingPanel, 1500);
  });
})();
</script>
'''

for rel in ["html/music-command/index.html", "html/music-command/index2.html"]:
    p = Path(rel)
    html = p.read_text(encoding="utf-8", errors="ignore")
    html = re.sub(r'<script id="tsm-music-tier-paywall-ui">.*?</script>', '', html, flags=re.S)
    html = html.replace("</body>", client + "\n</body>") if "</body>" in html else html + "\n" + client
    p.write_text(html, encoding="utf-8")

print("frontend tier/paywall UI inserted")
PY

node -c server.js

git add server.js html/music-command/index.html html/music-command/index2.html
git commit -m "Add Music tier pricing, paywall triggers, and upgrade UI" || true
git push origin main
fly deploy --local-only

echo "Testing billing state..."
curl -s https://tsm-shell.fly.dev/api/music/billing/state
echo
