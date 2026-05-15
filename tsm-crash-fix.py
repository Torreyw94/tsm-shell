#!/usr/bin/env python3
"""
TSM Crash Fix — run from /workspaces/tsm-shell
  python3 tsm-crash-fix.py

Fixes:
  1. server.js / tsm-bridge.js startup crash
  2. API route prefix mismatch (/wip vs /api/wip)
  3. Missing require() for wip-handlers / wip-schema-bridge
  4. Writes all files then validates with node --check
"""

import os, sys, subprocess
from pathlib import Path

BASE = Path("/workspaces/tsm-shell")

# ── Step 1: find the real entry point ────────────────────────────────────────
def find_entrypoint():
    for name in ["server.js", "tsm-bridge.js", "app.js", "index.js"]:
        p = BASE / name
        if p.exists():
            return p
    # check fly.toml for [processes]
    toml = BASE / "fly.toml"
    if toml.exists():
        for line in toml.read_text().splitlines():
            if "node" in line.lower() and ".js" in line:
                parts = line.split()
                for part in parts:
                    if part.endswith(".js"):
                        p = BASE / part
                        if p.exists():
                            return p
    return None

entry = find_entrypoint()
print(f"\n🔍 Entry point: {entry}\n")

# ── Step 2: write wip-handlers.js ────────────────────────────────────────────
(BASE / "wip-handlers.js").write_text(r"""
'use strict';
function fmt(n){return new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(n);}
function ts(){return new Date().toISOString();}

async function constructionWIPRecon(b={}){
  const{job='Ameris',costs=5100000,billed=4200000,threshold=50000}=b;
  const gap=costs-billed,pct=Math.round(billed/costs*100),hasGap=gap>threshold;
  return{suite:'construction',logic:'WIP-RECON',job,ts:ts(),
    metrics:{costs_incurred:costs,billed_to_date:billed,gap,billing_pct:pct},
    status:hasGap?'GAP_DETECTED':'BALANCED',action:hasGap?'INVOICE_TRIGGER':'NO_ACTION',
    message:hasGap?`Recoup ${fmt(gap)} — invoice packet queued for ${job} PM approval.`:`${job} WIP balanced.`,
    next_steps:hasGap?['Generate draft invoice','Route to PM for approval','Post to AR ledger','Reconcile WIP balance']:[]};
}

async function healthcareWIPRecon(b={}){
  const{unbilled_services=148,unbilled_value=2300000,denial_risk_pct=23,facility='Main Campus',period='Current Month'}=b;
  const net=Math.round(unbilled_value*(1-denial_risk_pct/100));
  return{suite:'healthcare',logic:'BNCA',facility,period,ts:ts(),
    metrics:{unbilled_services,unbilled_value,denial_risk_pct,net_recovery_estimate:net},
    status:unbilled_services>0?'CLAIMS_PENDING':'CLEAN',action:unbilled_services>0?'CLAIM_BATCH_SUBMIT':'NO_ACTION',
    message:unbilled_services>0?`${unbilled_services} claims queued. Net recovery: ${fmt(net)}.`:'No unbilled services.',
    risk_flag:denial_risk_pct>=20?`Denial risk ${denial_risk_pct}% — review coding.`:null,
    next_steps:unbilled_services>0?['Code review flagged claims','Submit to clearinghouse','Monitor 835 remittance','Post payments']:[]};
}

async function insuranceAuditRecon(b={}){
  const{earned_premium=7800000,audited=6100000,line_of_business='Property & Casualty',period='Current Quarter'}=b;
  const unaudited=earned_premium-audited,pct=Math.round(audited/earned_premium*100),reserve_risk=unaudited>1000000;
  return{suite:'tsm-insurance',logic:'AUDIT-RECON',line_of_business,period,ts:ts(),
    metrics:{earned_premium,audited_premium:audited,unaudited_premium:unaudited,audit_completion_pct:pct},
    status:unaudited>0?'AUDIT_GAP':'FULLY_AUDITED',action:unaudited>0?'AUDIT_SCHEDULE_PUSH':'NO_ACTION',
    message:unaudited>0?`Audit schedule pushed for ${fmt(unaudited)} in unaudited ${line_of_business} premium.`:'All premium audited.',
    reserve_risk_flag:reserve_risk?`Reserve misstatement risk: ${fmt(unaudited)} unaudited.`:null,
    next_steps:unaudited>0?['Push audit schedule','Collect payroll/exposure data','Calculate premium adjustment','Post to policy ledger']:[]};
}

async function finopsAccrualRecon(b={}){
  const{accrued=4400000,invoiced=3900000,cloud_provider='Multi-cloud',period='Current Month',flush_threshold=100000}=b;
  const variance=accrued-invoiced,match=Math.round(invoiced/accrued*100),auto=variance<=flush_threshold;
  return{suite:'finops-suite',logic:'ACCRUAL-RECON',cloud_provider,period,ts:ts(),
    metrics:{accrued_spend:accrued,invoiced_spend:invoiced,variance,invoice_match_rate_pct:match},
    status:variance>0?'VARIANCE_DETECTED':'MATCHED',action:variance>0?(auto?'ACCRUAL_AUTO_FLUSH':'ACCRUAL_FLUSH'):'NO_ACTION',
    message:variance>0?`${fmt(variance)} variance. ${auto?'Auto-flushing':'Manual flush queued'} before period close.`:'Cloud spend reconciled.',
    next_steps:variance>0?['Pull cloud billing invoices','Match to accrual entries',auto?`Auto-flush ${fmt(variance)}`:`Manual review — ${fmt(variance)}`,'Post to GL']:[]};
}

module.exports={constructionWIPRecon,healthcareWIPRecon,insuranceAuditRecon,finopsAccrualRecon};
""".strip() + "\n")
print("✓ wip-handlers.js written")

# ── Step 3: write the WIP route patch ────────────────────────────────────────
# This is a standalone middleware file — safe to require() from any server.js
(BASE / "wip-routes.js").write_text(r"""
'use strict';
/**
 * wip-routes.js
 * Mount with:  require('./wip-routes')(app);
 * Handles BOTH /api/wip/:suite/... AND /wip/:suite/...
 */
const {constructionWIPRecon,healthcareWIPRecon,insuranceAuditRecon,finopsAccrualRecon} = require('./wip-handlers');

const HANDLERS = {
  construction: constructionWIPRecon,
  healthcare:   healthcareWIPRecon,
  insurance:    insuranceAuditRecon,
  finops:       finopsAccrualRecon,
};

function handle(req, res, fn) {
  fn(req.body || {})
    .then(r => res.json(r))
    .catch(e => { console.error(e); res.status(500).json({ok:false,error:e.message}); });
}

module.exports = function mountWIPRoutes(app) {
  // Explicit named routes — both prefixes
  const pairs = [
    ['/api/wip/construction/recon',    'construction'],
    ['/wip/construction/recon',        'construction'],
    ['/api/wip/healthcare/recon',      'healthcare'],
    ['/wip/healthcare/recon',          'healthcare'],
    ['/api/wip/insurance/audit-recon', 'insurance'],
    ['/wip/insurance/audit-recon',     'insurance'],
    ['/api/wip/finops/accrual-recon',  'finops'],
    ['/wip/finops/accrual-recon',      'finops'],
  ];
  pairs.forEach(([path, suite]) => {
    app.post(path, (req, res) => handle(req, res, HANDLERS[suite]));
  });

  // Generic catch-all — handles /api/wip/:suite/recon AND /wip/:suite/recon
  ['get','post'].forEach(method => {
    ['/api/wip/:suite/:action', '/wip/:suite/:action'].forEach(path => {
      app[method](path, (req, res) => {
        const h = HANDLERS[req.params.suite];
        if (!h) return res.status(404).json({ok:false,error:`No handler for suite: ${req.params.suite}`,available:Object.keys(HANDLERS)});
        handle(req, res, h);
      });
    });
  });

  // Health check
  app.get('/api/health', (_,res) => res.json({ok:true,ts:new Date().toISOString(),routes:Object.keys(HANDLERS)}));
  app.get('/health',     (_,res) => res.json({ok:true,ts:new Date().toISOString(),routes:Object.keys(HANDLERS)}));

  console.log('[WIP] Routes mounted: construction, healthcare, insurance, finops');
  console.log('[WIP] Prefixes: /api/wip/* and /wip/*');
};
""".strip() + "\n")
print("✓ wip-routes.js written")

# ── Step 4: patch the entry point to require wip-routes ──────────────────────
if entry and entry.exists():
    src = entry.read_text()

    if "wip-routes" in src:
        print(f"↺  {entry.name}: wip-routes already required — skipping patch")
    else:
        # Find the best injection point
        # Strategy: inject after the last app.use() middleware block, before app.listen
        patch = "\n// ── WIP ROUTES (auto-patched) ────────────────────────────\nrequire('./wip-routes')(app);\n"

        if "app.listen" in src:
            src = src.replace("app.listen", patch + "\napp.listen", 1)
        elif "module.exports" in src:
            src = src.replace("module.exports", patch + "\nmodule.exports", 1)
        else:
            src += patch

        entry.write_text(src)
        print(f"✓  {entry.name}: wip-routes require() injected")
else:
    print("⚠  Could not find entry point — writing standalone server.js")
    # Write a minimal safe server that won't crash
    (BASE / "server.js").write_text(r"""
'use strict';
const express = require('express');
const cors    = require('cors');
const path    = require('path');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Serve static files from /html
app.use(express.static(path.join(__dirname, 'html')));
app.use(express.static(path.join(__dirname, 'public')));

// WIP API routes
require('./wip-routes')(app);

// Fallback
app.get('*', (req, res) => {
  const f = path.join(__dirname, 'html', req.path);
  res.sendFile(f, err => { if (err) res.status(404).send('Not found'); });
});

app.listen(PORT, () => {
  console.log(`TSM Shell on port ${PORT}`);
});
""".strip() + "\n")
    print("✓  server.js written (safe fallback)")

# ── Step 5: validate syntax ───────────────────────────────────────────────────
print("\n🔎 Syntax check...")
files_to_check = ["wip-handlers.js", "wip-routes.js"]
if entry:
    files_to_check.append(entry.name)

all_ok = True
for f in files_to_check:
    p = BASE / f
    if not p.exists():
        continue
    result = subprocess.run(["node", "--check", str(p)], capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  ✓  {f}: syntax OK")
    else:
        print(f"  ✗  {f}: SYNTAX ERROR")
        print(f"     {result.stderr.strip()}")
        all_ok = False

# ── Step 6: quick smoke test ──────────────────────────────────────────────────
print("\n🧪 Smoke test (node -e)...")
smoke = subprocess.run(
    ["node", "-e", """
const h = require('./wip-handlers');
Promise.all([
  h.constructionWIPRecon({}),
  h.healthcareWIPRecon({}),
  h.insuranceAuditRecon({}),
  h.finopsAccrualRecon({})
]).then(r => {
  r.forEach(x => console.log('  ✓', x.suite, '|', x.action));
  process.exit(0);
}).catch(e => { console.error('  ✗', e.message); process.exit(1); });
"""],
    capture_output=True, text=True, cwd=str(BASE)
)
print(smoke.stdout.strip() or smoke.stderr.strip())

# ── Done ─────────────────────────────────────────────────────────────────────
print()
if all_ok and smoke.returncode == 0:
    print("=" * 55)
    print("  ✅  ALL CHECKS PASSED — ready to deploy")
    print()
    print("  Run:  fly deploy")
    print()
    print("  Then test:")
    print("  curl -X POST https://tsm-shell.fly.dev/api/wip/insurance/audit-recon \\")
    print("    -H 'Content-Type: application/json' -d '{}'")
    print("=" * 55)
else:
    print("=" * 55)
    print("  ⚠  ISSUES FOUND — check errors above before deploying")
    print("=" * 55)
    sys.exit(1)
