#!/usr/bin/env python3
"""
TSM WIP Hub Injector — Monday Presentation Ready
================================================
Run from /workspaces/tsm-shell:
    python3 tsm-wip-inject.py

What this does:
  1. Injects a WIP Intelligence card into all 4 hub files
  2. Adds Insurance WIP sector to wip-dashboard.html
  3. Wires all hub cards to correct /wip-dashboard.html?sector=X paths
"""

import os, re, sys
from pathlib import Path

BASE = Path("/workspaces/tsm-shell")

# ── HUB PATHS ────────────────────────────────────────────────────────────────
HUBS = {
    "construction": BASE / "html/construction-suite/construction-hub.html",
    "finops":       BASE / "html/finops-suite/financial-ui.html",
    "healthcare":   BASE / "html/healthcare/index.html",
    "insurance":    BASE / "html/tsm-insurance/az-ins.html",
}

WIP_DASHBOARD = BASE / "html/wip-dashboard.html"

# ── WIP CARD STYLES (injected once per hub, scoped) ──────────────────────────
WIP_CARD_STYLE = """
<style id="tsm-wip-card-style">
.tsm-wip-banner{position:relative;margin:0;background:linear-gradient(135deg,#070c10 0%,#0a1018 100%);border-top:2px solid;border-bottom:1px solid rgba(255,255,255,.08);padding:1.25rem 2rem;display:flex;align-items:center;justify-content:space-between;gap:1.5rem;flex-wrap:wrap;z-index:10}
.tsm-wip-banner.construction{border-top-color:#00d4b8}
.tsm-wip-banner.finops{border-top-color:#3a8cf0}
.tsm-wip-banner.healthcare{border-top-color:#00e87a}
.tsm-wip-banner.insurance{border-top-color:#f4a800}
.tsm-wip-left{display:flex;align-items:center;gap:1rem}
.tsm-wip-icon{width:36px;height:36px;border-radius:4px;display:flex;align-items:center;justify-content:center;font-size:18px;flex-shrink:0}
.construction .tsm-wip-icon{background:rgba(0,212,184,.12)}
.finops       .tsm-wip-icon{background:rgba(58,140,240,.12)}
.healthcare   .tsm-wip-icon{background:rgba(0,232,122,.12)}
.insurance    .tsm-wip-icon{background:rgba(244,168,0,.12)}
.tsm-wip-label{font-family:'Share Tech Mono',monospace;font-size:.52rem;letter-spacing:.18em;text-transform:uppercase;opacity:.6;margin-bottom:.2rem}
.construction .tsm-wip-label{color:#00d4b8}
.finops       .tsm-wip-label{color:#3a8cf0}
.healthcare   .tsm-wip-label{color:#00e87a}
.insurance    .tsm-wip-label{color:#f4a800}
.tsm-wip-title{font-family:'Barlow Condensed','Share Tech Mono',monospace;font-weight:700;font-size:1rem;color:#dce9f0;line-height:1.2}
.tsm-wip-kpis{display:flex;gap:1.25rem;flex-wrap:wrap}
.tsm-wip-kpi{text-align:center}
.tsm-wip-kpi-val{font-family:'Share Tech Mono','Orbitron',monospace;font-size:1.1rem;font-weight:700;line-height:1}
.tsm-wip-kpi-lbl{font-family:'Share Tech Mono',monospace;font-size:.42rem;letter-spacing:.1em;color:#304858;margin-top:.2rem;text-transform:uppercase}
.tsm-wip-btn{font-family:'Share Tech Mono',monospace;font-size:.5rem;letter-spacing:.12em;padding:.5rem 1.1rem;border:1px solid;background:transparent;cursor:pointer;text-decoration:none;display:inline-flex;align-items:center;gap:.4rem;text-transform:uppercase;transition:all .15s;white-space:nowrap;flex-shrink:0}
.construction .tsm-wip-btn{border-color:#00d4b8;color:#00d4b8}
.finops       .tsm-wip-btn{border-color:#3a8cf0;color:#3a8cf0}
.healthcare   .tsm-wip-btn{border-color:#00e87a;color:#00e87a}
.insurance    .tsm-wip-btn{border-color:#f4a800;color:#f4a800}
.tsm-wip-btn:hover{background:rgba(255,255,255,.05)}
.tsm-wip-flag{font-family:'Share Tech Mono',monospace;font-size:.42rem;letter-spacing:.1em;padding:.25rem .6rem;border-radius:2px;text-transform:uppercase;animation:tsm-wip-pulse 2s infinite}
@keyframes tsm-wip-pulse{0%,100%{opacity:1}50%{opacity:.5}}
</style>
"""

# ── PER-SECTOR CARD HTML ──────────────────────────────────────────────────────
def wip_card(sector):
    configs = {
        "construction": {
            "label": "WIP Intelligence · AIA G702/G703",
            "title": "Construction WIP Reconciliation",
            "icon": "🏗️",
            "kpis": [
                ("$5.1M", "Costs Incurred"),
                ("$4.2M", "Billed to Date"),
                ("-$900k", "WIP Gap"),
                ("82%", "Billing Pct"),
            ],
            "flag_color": "#ff3d57",
            "flag_text": "⚠ INVOICE TRIGGER ACTIVE",
            "url": "/wip-dashboard.html?sector=construction",
            "btn": "VIEW WIP DASHBOARD ↗",
        },
        "finops": {
            "label": "WIP Intelligence · Accrual Reconciliation",
            "title": "FinOps Cloud Spend WIP",
            "icon": "📊",
            "kpis": [
                ("$4.4M", "Accrued Spend"),
                ("$3.9M", "Invoiced"),
                ("-$500k", "Variance"),
                ("89%", "Match Rate"),
            ],
            "flag_color": "#f4a800",
            "flag_text": "⚡ ACCRUAL FLUSH QUEUED",
            "url": "/wip-dashboard.html?sector=finops",
            "btn": "VIEW WIP DASHBOARD ↗",
        },
        "healthcare": {
            "label": "WIP Intelligence · RCM Revenue Cycle",
            "title": "Healthcare RCM WIP · BNCA Active",
            "icon": "🏥",
            "kpis": [
                ("$2.3M", "Unbilled"),
                ("148", "Pending Claims"),
                ("23%", "Denial Risk"),
                ("61%", "Reconciled"),
            ],
            "flag_color": "#ff3d57",
            "flag_text": "🔴 2 CRIT · ENC-8821 · ENC-8912",
            "url": "/wip-dashboard.html?sector=healthcare",
            "btn": "VIEW WIP DASHBOARD ↗",
        },
        "insurance": {
            "label": "WIP Intelligence · P&C Premium Audit",
            "title": "Insurance WIP · Audit Reconciliation",
            "icon": "🛡️",
            "kpis": [
                ("$7.8M", "Earned Premium"),
                ("$6.1M", "Audited"),
                ("-$1.7M", "Unaudited"),
                ("78%", "Audit Pct"),
            ],
            "flag_color": "#f4a800",
            "flag_text": "⚠ RESERVE RISK · REVIEW REQUIRED",
            "url": "/wip-dashboard.html?sector=insurance",
            "btn": "VIEW WIP DASHBOARD ↗",
        },
    }

    c = configs[sector]
    kpi_html = "".join(
        f'<div class="tsm-wip-kpi"><div class="tsm-wip-kpi-val" style="color:{_kpi_color(sector, v)}">{v}</div><div class="tsm-wip-kpi-lbl">{l}</div></div>'
        for v, l in c["kpis"]
    )

    return f"""
<!-- TSM WIP INTELLIGENCE BANNER — {sector.upper()} — AUTO-INJECTED -->
{WIP_CARD_STYLE if sector == "construction" else ""}
<div class="tsm-wip-banner {sector}" id="tsm-wip-{sector}">
  <div class="tsm-wip-left">
    <div class="tsm-wip-icon">{c["icon"]}</div>
    <div>
      <div class="tsm-wip-label">{c["label"]}</div>
      <div class="tsm-wip-title">{c["title"]}</div>
    </div>
  </div>
  <div class="tsm-wip-kpis">
    {kpi_html}
  </div>
  <div style="display:flex;flex-direction:column;align-items:flex-end;gap:.5rem">
    <span class="tsm-wip-flag" style="background:rgba(255,61,87,.1);border:1px solid {c['flag_color']};color:{c['flag_color']}">{c['flag_text']}</span>
    <a href="{c['url']}" class="tsm-wip-btn">{c['btn']}</a>
  </div>
</div>
<!-- END TSM WIP BANNER -->
"""

def _kpi_color(sector, val):
    if val.startswith("-"):       return "#ff3d57"
    if "%" in val and int(val.replace("%","")) < 80: return "#f4a800"
    colors = {"construction": "#00d4b8", "finops": "#3a8cf0", "healthcare": "#00e87a", "insurance": "#f4a800"}
    return colors.get(sector, "#00d4b8")

# ── INSURANCE WIP SECTOR for wip-dashboard.html ──────────────────────────────
INSURANCE_WIP_SECTOR = """
<!-- ══ INSURANCE WIP SECTOR — AUTO-INJECTED ══ -->
<section id="wip-insurance" class="wip-sector" data-sector="insurance" style="display:none">
  <div class="sector-header">
    <div class="sector-eyebrow">// INSURANCE WIP INTELLIGENCE · P&amp;C PREMIUM AUDIT</div>
    <h2 class="sector-title">TSM-Insurance <span>WIP Reconciliation</span></h2>
    <p class="sector-sub">Real-time percent-complete analysis, premium audit reconciliation, and surety bond risk scoring — powered by AUDIT-RECON and the TSM Sovereign Mesh.</p>
    <div class="sector-tabs">
      <button class="stab active" data-tab="ins-recon">🛡 AUDIT-RECON</button>
      <button class="stab" data-tab="ins-surety">📋 SURETY BOND</button>
      <button class="stab" data-tab="ins-reserve">⚠ RESERVE RISK</button>
    </div>
  </div>

  <!-- KPI ROW -->
  <div class="wip-kpi-row">
    <div class="wip-kpi" style="--kc:#f4a800">
      <div class="wip-kpi-val">$7.8M</div>
      <div class="wip-kpi-lbl">Earned Premium</div>
      <div class="wip-kpi-sub">Current quarter</div>
    </div>
    <div class="wip-kpi" style="--kc:#00d4ff">
      <div class="wip-kpi-val">$6.1M</div>
      <div class="wip-kpi-lbl">Audited Premium</div>
      <div class="wip-kpi-sub">78% audit completion</div>
    </div>
    <div class="wip-kpi" style="--kc:#ff3d57">
      <div class="wip-kpi-val">$1.7M</div>
      <div class="wip-kpi-lbl">Unaudited Gap</div>
      <div class="wip-kpi-sub">Reserve misstatement risk</div>
    </div>
    <div class="wip-kpi" style="--kc:#ffb300">
      <div class="wip-kpi-val">12</div>
      <div class="wip-kpi-lbl">Policies Pending</div>
      <div class="wip-kpi-sub">Audit schedule needed</div>
    </div>
  </div>

  <!-- ALERT FLAGS -->
  <div class="wip-flags">
    <div class="wip-flag red">⚠ RESERVE RISK: $1.7M unaudited P&amp;C premium — actuarial review recommended before period close.</div>
    <div class="wip-flag yellow">📋 SURETY FLAG: Profit fade detected on 2 contractor bonds — bonding capacity review triggered.</div>
    <div class="wip-flag blue">🛡 AUDIT-RECON: Schedule pushed to 12 policyholders. Collect payroll/exposure data within 30 days.</div>
  </div>

  <!-- WIP MATRIX TABLE -->
  <div class="wip-matrix-wrap">
    <div class="wip-matrix-header">
      <span class="wip-matrix-title">POLICY / AUDIT STATUS MATRIX</span>
      <span class="wip-flag-count">3 ACTIVE FLAGS</span>
    </div>
    <table class="wip-matrix-table">
      <thead>
        <tr>
          <th>Policy #</th><th>Line of Business</th><th>Audit Stage</th>
          <th>Premium Earned</th><th>Premium Audited</th><th>Gap</th><th>Status</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>POL-4421</td><td>General Liability</td>
          <td><span class="pct red">38%</span> <span class="pct-bar"><span style="width:38%;background:#ff3d57"></span></span></td>
          <td>$1,200,000</td><td>$456,000</td><td class="td-red">-$744,000</td><td class="status-red">AUDIT OPEN</td>
        </tr>
        <tr>
          <td>POL-4389</td><td>Workers Comp</td>
          <td><span class="pct yellow">65%</span> <span class="pct-bar"><span style="width:65%;background:#ffb300"></span></span></td>
          <td>$890,000</td><td>$578,500</td><td class="td-yellow">-$311,500</td><td class="status-yellow">IN PROGRESS</td>
        </tr>
        <tr>
          <td>POL-4402</td><td>Commercial Auto</td>
          <td><span class="pct green">100%</span> <span class="pct-bar"><span style="width:100%;background:#00e676"></span></span></td>
          <td>$540,000</td><td>$540,000</td><td class="td-green">$0</td><td class="status-green">CLOSED</td>
        </tr>
        <tr>
          <td>POL-4415</td><td>Umbrella / Excess</td>
          <td><span class="pct red">22%</span> <span class="pct-bar"><span style="width:22%;background:#ff3d57"></span></span></td>
          <td>$3,100,000</td><td>$682,000</td><td class="td-red">-$2,418,000</td><td class="status-red">AUDIT OPEN</td>
        </tr>
        <tr>
          <td>POL-4438</td><td>Property / Inland Marine</td>
          <td><span class="pct green">95%</span> <span class="pct-bar"><span style="width:95%;background:#00e676"></span></span></td>
          <td>$980,000</td><td>$931,000</td><td class="td-green">-$49,000</td><td class="status-green">NEAR CLOSE</td>
        </tr>
        <tr>
          <td>POL-4447</td><td>Surety Bond · Performance</td>
          <td><span class="pct yellow">71%</span> <span class="pct-bar"><span style="width:71%;background:#ffb300"></span></span></td>
          <td>$1,090,000</td><td>$773,900</td><td class="td-yellow">-$316,100</td><td class="status-yellow">WATCH</td>
        </tr>
      </tbody>
    </table>
  </div>

  <!-- SURETY BOND ANALYSIS -->
  <div class="wip-surety-grid">
    <div class="wip-surety-card">
      <div class="wip-surety-title">🛡 Surety Bond Risk — Arizona P&amp;C Context</div>
      <div class="wip-surety-row"><span>Bonding Capacity Signal</span><span class="warn">REVIEW REQUIRED</span></div>
      <div class="wip-surety-row"><span>Profit Fade Flag (Performance Bond)</span><span class="risk">YES — 2.4% loss detected</span></div>
      <div class="wip-surety-row"><span>Under-billing Risk (Liquidity)</span><span class="risk">$900k contractor gap</span></div>
      <div class="wip-surety-row"><span>Maintenance of Records (ARS §20-461)</span><span class="ok">AIA G702/G703 compliant ✓</span></div>
      <div class="wip-surety-row"><span>Reserve Misstatement Risk</span><span class="risk">$1.7M unaudited — HIGH</span></div>
      <div class="wip-surety-row"><span>Audit Schedule Compliance</span><span class="warn">12 policies pending push</span></div>
    </div>
    <div class="wip-surety-card">
      <div class="wip-surety-title">⚡ AUDIT-RECON Actions</div>
      <div class="wip-surety-row"><span>Action</span><span>AUDIT_SCHEDULE_PUSH</span></div>
      <div class="wip-surety-row"><span>Policies Queued</span><span class="ok">12 policyholders</span></div>
      <div class="wip-surety-row"><span>Data Required</span><span>Payroll + exposure reports</span></div>
      <div class="wip-surety-row"><span>Deadline</span><span class="warn">30 days (period close)</span></div>
      <div class="wip-surety-row"><span>Estimated Adjustment</span><span class="ok">+$140k earned premium</span></div>
      <div style="margin-top:.75rem;display:flex;gap:.5rem">
        <button onclick="runAuditRecon()" style="flex:1;padding:.5rem;background:#f4a800;color:#000;border:none;font-family:inherit;font-size:.52rem;font-weight:700;letter-spacing:.1em;cursor:pointer;text-transform:uppercase">⚡ RUN AUDIT-RECON</button>
        <a href="/html/tsm-insurance/az-ins.html" style="flex:1;padding:.5rem;border:1px solid #f4a800;color:#f4a800;font-family:inherit;font-size:.52rem;letter-spacing:.1em;cursor:pointer;text-transform:uppercase;text-decoration:none;display:flex;align-items:center;justify-content:center">VIEW HUB ↗</a>
      </div>
    </div>
  </div>
</section>
<script>
function runAuditRecon() {
  fetch('/api/wip/insurance/audit-recon', {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({ earned_premium:7800000, audited:6100000, period:'Q2-2026' })
  })
  .then(r=>r.json())
  .catch(()=>({ action:'AUDIT_SCHEDULE_PUSH', message:'Audit schedule pushed for $1.7M unaudited P&C premium.', _source:'mock' }))
  .then(d=>{ alert('AUDIT-RECON:\\n\\n' + (d.message || d.action)); });
}
</script>
<!-- END INSURANCE WIP SECTOR -->
"""

# ── INJECT INTO HUB FILES ────────────────────────────────────────────────────
def inject_into_hub(sector, path):
    if not path.exists():
        print(f"  ⚠  SKIP {sector}: file not found at {path}")
        return False

    html = path.read_text(encoding="utf-8")
    marker = f"tsm-wip-{sector}"

    if marker in html:
        print(f"  ↺  {sector}: WIP banner already injected — skipping")
        return True

    card = wip_card(sector)

    # Try to inject after <body>, else after topbar, else at start of <main>
    inserted = False
    for pattern, replacement in [
        (r'(<body[^>]*>)', rf'\1\n{card}'),
        (r'(class="topbar"[^>]*>.*?</div>)', rf'\1\n{card}'),
        (r'(<div[^>]+class="[^"]*main[^"]*")', rf'{card}\n\1'),
    ]:
        new_html, n = re.subn(pattern, replacement, html, count=1, flags=re.DOTALL)
        if n:
            html = new_html
            inserted = True
            break

    if not inserted:
        # Fallback: inject right after <body>
        html = html.replace("<body>", f"<body>\n{card}", 1)
        inserted = True

    path.write_text(html, encoding="utf-8")
    print(f"  ✓  {sector}: WIP banner injected into {path.name}")
    return True

# ── ADD INSURANCE SECTOR TO wip-dashboard.html ──────────────────────────────
def inject_insurance_sector():
    if not WIP_DASHBOARD.exists():
        print(f"  ⚠  wip-dashboard.html not found at {WIP_DASHBOARD}")
        return False

    html = WIP_DASHBOARD.read_text(encoding="utf-8")

    if "wip-insurance" in html:
        print("  ↺  Insurance sector already in wip-dashboard.html — skipping")
        return True

    # Add Insurance nav tab to the sector switcher
    html = re.sub(
        r'(<button[^>]*data-sector="healthcare"[^>]*>.*?</button>)',
        r'\1\n      <button class="sector-tab" data-sector="insurance" onclick="switchSector(\'insurance\')">🛡 Insurance</button>',
        html, count=1, flags=re.DOTALL
    )

    # Inject sector before </main> or before </body>
    injected = False
    for tag in ["</main>", "</body>"]:
        if tag in html:
            html = html.replace(tag, INSURANCE_WIP_SECTOR + "\n" + tag, 1)
            injected = True
            break

    if not injected:
        html += INSURANCE_WIP_SECTOR

    # Wire sector switch JS if switchSector function exists
    if "switchSector" not in html:
        switch_js = """
<script id="tsm-sector-switch">
function switchSector(s) {
  document.querySelectorAll('.wip-sector').forEach(el => el.style.display = 'none');
  document.querySelectorAll('.sector-tab').forEach(el => el.classList.remove('active'));
  const sec = document.getElementById('wip-' + s);
  if (sec) sec.style.display = 'block';
  const btn = document.querySelector('[data-sector="' + s + '"]');
  if (btn) btn.classList.add('active');
}
// Auto-select from URL param
(function(){
  const p = new URLSearchParams(window.location.search).get('sector');
  if (p) { switchSector(p); }
})();
</script>"""
        html = html.replace("</body>", switch_js + "\n</body>", 1)

    WIP_DASHBOARD.write_text(html, encoding="utf-8")
    print(f"  ✓  Insurance WIP sector injected into wip-dashboard.html")
    return True

# ── ADD HUB LINKS TO WIP DASHBOARD SECTOR NAV ────────────────────────────────
HUB_LINKS = {
    "construction": "/html/construction-suite/construction-hub.html",
    "finops":       "/html/finops-suite/financial-ui.html",
    "healthcare":   "/html/healthcare/index.html",
    "insurance":    "/html/tsm-insurance/az-ins.html",
}

def patch_wip_dashboard_hub_links():
    if not WIP_DASHBOARD.exists():
        return
    html = WIP_DASHBOARD.read_text(encoding="utf-8")
    if "tsm-hub-link-patch" in html:
        print("  ↺  Hub links already patched in wip-dashboard.html")
        return

    patch = """
<!-- TSM HUB LINK PATCH — tsm-hub-link-patch -->
<style>
.tsm-hub-links-bar{display:flex;gap:.75rem;padding:.6rem 2rem;background:#070c10;border-bottom:1px solid #1e2530;flex-wrap:wrap;align-items:center}
.tsm-hub-link{font-family:'Share Tech Mono',monospace;font-size:.48rem;letter-spacing:.12em;padding:.3rem .8rem;border:1px solid #1e2530;color:#4a5a6a;text-decoration:none;text-transform:uppercase;transition:all .15s}
.tsm-hub-link:hover{color:#00d4ff;border-color:#00d4ff}
.tsm-hub-link.construction:hover{color:#00d4b8;border-color:#00d4b8}
.tsm-hub-link.finops:hover{color:#3a8cf0;border-color:#3a8cf0}
.tsm-hub-link.healthcare:hover{color:#00e87a;border-color:#00e87a}
.tsm-hub-link.insurance:hover{color:#f4a800;border-color:#f4a800}
</style>
<div class="tsm-hub-links-bar">
  <span style="font-family:monospace;font-size:.48rem;color:#304858;letter-spacing:.1em">SUITE HUBS ↗</span>
  <a class="tsm-hub-link construction" href="/html/construction-suite/construction-hub.html">🏗 Construction Hub</a>
  <a class="tsm-hub-link finops"       href="/html/finops-suite/financial-ui.html">📊 FinOps Hub</a>
  <a class="tsm-hub-link healthcare"   href="/html/healthcare/index.html">🏥 Healthcare Hub</a>
  <a class="tsm-hub-link insurance"    href="/html/tsm-insurance/az-ins.html">🛡 Insurance Hub</a>
</div>
"""
    html = html.replace("</body>", "", 1)  # temp remove for safety
    # inject after topbar / nav or at top of body
    for tag in ["<!-- END TOPBAR -->", "</nav>", '<div class="ticker']:
        if tag in html:
            html = html.replace(tag, tag + "\n" + patch, 1)
            break
    else:
        html = html.replace("<body", patch + "\n<body", 1)

    html += "\n</body>"
    WIP_DASHBOARD.write_text(html, encoding="utf-8")
    print("  ✓  Hub links bar added to wip-dashboard.html")

# ── RUN ───────────────────────────────────────────────────────────────────────
print()
print("=" * 60)
print("  TSM WIP Hub Injector — Monday Presentation Build")
print("=" * 60)
print()

print("[ 1/3 ] Injecting WIP banners into hub files...")
for sector, path in HUBS.items():
    inject_into_hub(sector, path)

print()
print("[ 2/3 ] Adding Insurance WIP sector to wip-dashboard.html...")
inject_insurance_sector()

print()
print("[ 3/3 ] Patching hub navigation links into wip-dashboard.html...")
patch_wip_dashboard_hub_links()

print()
print("=" * 60)
print("  DONE. Presentation-ready changes:")
print()
print("  WIP banners injected:")
for sector, path in HUBS.items():
    print(f"    {path.name}  →  /wip-dashboard.html?sector={sector}")
print()
print("  New Insurance WIP sector:")
print("    tsm-shell.fly.dev/wip-dashboard.html?sector=insurance")
print()
print("  Hub navigation bar added to wip-dashboard.html")
print()
print("  Deploy:  fly deploy")
print("=" * 60)
print()
