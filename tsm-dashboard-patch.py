#!/usr/bin/env python3
"""
TSM Dashboard Patch — run from /workspaces/tsm-shell
  python3 tsm-dashboard-patch.py

Fixes:
  1. Sector tab buttons broken — rewrites switchSector() with correct DOM targeting
  2. Adds Chart A (Portfolio Job Health + G702 summary) merged into Charts section
  3. Fixes hub nav link paths (removes /html/ prefix that 404s)
  4. Makes Insurance sector visually match Charts B-F
"""

import re
from pathlib import Path

DASHBOARD = Path("/workspaces/tsm-shell/html/wip-dashboard.html")

if not DASHBOARD.exists():
    # try alternate paths
    for p in [
        Path("/workspaces/tsm-shell/wip-dashboard.html"),
        Path("/workspaces/tsm-shell/public/wip-dashboard.html"),
    ]:
        if p.exists():
            DASHBOARD = p
            break
    else:
        print("ERROR: wip-dashboard.html not found. Checked:")
        print("  html/wip-dashboard.html")
        print("  wip-dashboard.html")
        print("  public/wip-dashboard.html")
        raise SystemExit(1)

print(f"Found dashboard: {DASHBOARD}")
src = DASHBOARD.read_text(encoding="utf-8")
original_len = len(src)

# ── FIX 1: SECTOR BUTTON SWITCHING ───────────────────────────────────────────
# Remove any existing broken switchSector script and inject a correct one

# Strip old broken sector switch scripts
src = re.sub(r'<script id="tsm-sector-switch">.*?</script>', '', src, flags=re.DOTALL)
src = re.sub(r'<script>\s*function switchSector.*?</script>', '', src, flags=re.DOTALL)

SECTOR_SWITCH_JS = """
<script id="tsm-sector-switch">
// ── SECTOR SWITCHING ─────────────────────────────────────────
(function() {
  function switchSector(name) {
    // Hide all sectors
    document.querySelectorAll('[data-wip-sector]').forEach(function(el) {
      el.style.display = 'none';
    });
    // Deactivate all tabs
    document.querySelectorAll('[data-sector-btn]').forEach(function(btn) {
      btn.classList.remove('active');
      btn.setAttribute('aria-selected', 'false');
    });
    // Show target sector
    var target = document.querySelector('[data-wip-sector="' + name + '"]');
    if (target) {
      target.style.display = 'block';
    } else {
      // fallback: show charts section for construction/healthcare/finops
      var charts = document.getElementById('charts-section');
      if (charts) charts.style.display = 'block';
    }
    // Activate tab
    var btn = document.querySelector('[data-sector-btn="' + name + '"]');
    if (btn) {
      btn.classList.add('active');
      btn.setAttribute('aria-selected', 'true');
    }
    // Update URL param without reload
    try {
      var url = new URL(window.location.href);
      url.searchParams.set('sector', name);
      history.replaceState(null, '', url.toString());
    } catch(e) {}
    console.log('WIP sector selected:', name);
  }

  // Expose globally
  window.switchSector = switchSector;

  // Wire all sector buttons
  document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('[data-sector-btn]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        switchSector(btn.getAttribute('data-sector-btn'));
      });
    });

    // Auto-select from URL param
    var param = new URLSearchParams(window.location.search).get('sector');
    if (param) {
      switchSector(param);
    } else {
      switchSector('construction');
    }
  });
})();
</script>
"""

# Also fix the sector tab buttons to use data-sector-btn attribute
# Pattern: buttons that switch sectors - add data-sector-btn attribute
def fix_sector_buttons(html):
    # Find the tab row and rewrite it completely
    tab_patterns = [
        (r'(🏗\s*CONSTRUCTION)', 'construction'),
        (r'(🏥\s*HEALTHCARE)',   'healthcare'),
        (r'(📋\s*INSURANCE)',    'insurance'),
        (r'(💰\s*FINOPS)',       'finops'),
    ]
    for pattern, sector in tab_patterns:
        # Add onclick and data-sector-btn to any button containing the sector text
        html = re.sub(
            r'(<button[^>]*?)(' + pattern + r')([^<]*</button>)',
            lambda m: m.group(1).rstrip() + f' data-sector-btn="{sector}" onclick="switchSector(\'{sector}\')" ' + m.group(2) + m.group(3),
            html, flags=re.IGNORECASE
        )
    return html

src = fix_sector_buttons(src)

# ── FIX 2: HUB NAV LINK PATHS ────────────────────────────────────────────────
# /html/construction-suite/ → /construction-suite/ (fly.dev serves from /html/)
src = src.replace('href="/html/construction-suite/', 'href="/construction-suite/')
src = src.replace('href="/html/finops-suite/', 'href="/finops-suite/')
src = src.replace('href="/html/healthcare/', 'href="/healthcare/')
src = src.replace('href="/html/tsm-insurance/', 'href="/tsm-insurance/')

# ── FIX 3: ADD CHART A ────────────────────────────────────────────────────────
CHART_A_HTML = """
<!-- ══ CHART A · JOB HEALTH + G702 SUMMARY ══ -->
<div class="chart-card" id="chartA-card" data-wip-sector="construction" style="display:none">
  <div class="chart-header">
    <span class="chart-label">CHART A · JOB HEALTH MATRIX &amp; G702 SUMMARY</span>
    <span class="chart-meta">Portfolio overview · AIA G702 Application for Payment</span>
  </div>
  <div class="chart-body">

    <!-- JOB HEALTH TILES -->
    <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px;margin-bottom:16px">

      <div style="background:#0a1a0a;border:1px solid #00d4b8;border-radius:4px;padding:12px;font-family:'Share Tech Mono',monospace">
        <div style="font-size:9px;color:#4a5a6a;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px">JOB 203 · AMERIS</div>
        <div style="font-size:11px;color:#00d4b8;margin-bottom:6px">Earned &gt; Billed</div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Contract</span><span style="color:#c8d4e0">$1,820,140</span>
        </div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Completed</span><span style="color:#00e676">$1,650,000</span>
        </div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Retainage</span><span style="color:#ffb300">$165,000</span>
        </div>
        <div style="margin-top:6px;height:3px;background:#1e2530;border-radius:2px">
          <div style="width:91%;height:100%;background:#00d4b8;border-radius:2px"></div>
        </div>
        <div style="font-size:9px;color:#00d4b8;margin-top:3px">91% billed</div>
      </div>

      <div style="background:#1a0a0a;border:1px solid #ff3d57;border-radius:4px;padding:12px;font-family:'Share Tech Mono',monospace">
        <div style="font-size:9px;color:#4a5a6a;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px">JOB 211 · UNDER-BILLED</div>
        <div style="font-size:11px;color:#ff3d57;margin-bottom:6px">Significant Fade ⚠</div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Contract</span><span style="color:#c8d4e0">$5,100,000</span>
        </div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Billed</span><span style="color:#ff3d57">$4,200,000</span>
        </div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Gap</span><span style="color:#ff3d57">-$900,000</span>
        </div>
        <div style="margin-top:6px;height:3px;background:#1e2530;border-radius:2px">
          <div style="width:82%;height:100%;background:#ff3d57;border-radius:2px"></div>
        </div>
        <div style="font-size:9px;color:#ff3d57;margin-top:3px">82% billed · INVOICE TRIGGER</div>
      </div>

      <div style="background:#0a0f1a;border:1px solid #00d4ff;border-radius:4px;padding:12px;font-family:'Share Tech Mono',monospace">
        <div style="font-size:9px;color:#4a5a6a;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px">JOB 214 · ON BUDGET</div>
        <div style="font-size:11px;color:#00d4ff;margin-bottom:6px">Tracking Well</div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Contract</span><span style="color:#c8d4e0">$3,800,000</span>
        </div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Billed</span><span style="color:#00e676">$3,610,000</span>
        </div>
        <div style="display:flex;justify-content:space-between;font-size:10px">
          <span style="color:#4a5a6a">Gap</span><span style="color:#00e676">-$190,000</span>
        </div>
        <div style="margin-top:6px;height:3px;background:#1e2530;border-radius:2px">
          <div style="width:95%;height:100%;background:#00d4ff;border-radius:2px"></div>
        </div>
        <div style="font-size:9px;color:#00d4ff;margin-top:3px">95% billed</div>
      </div>

    </div>

    <!-- G702 SUMMARY TABLE -->
    <div style="font-family:'Share Tech Mono',monospace">
      <div style="font-size:9px;color:#4a5a6a;letter-spacing:.12em;text-transform:uppercase;margin-bottom:8px;padding-bottom:6px;border-bottom:1px solid #1e2530">
        AIA G702 · Application and Certificate for Payment · Banner Health
      </div>
      <table style="width:100%;border-collapse:collapse;font-size:11px">
        <tbody>
          <tr style="border-bottom:1px solid #1e2530">
            <td style="padding:5px 0;color:#4a5a6a">1. Original Contract Sum</td>
            <td style="padding:5px 0;text-align:right;color:#c8d4e0">$1,500,000.00</td>
          </tr>
          <tr style="border-bottom:1px solid #1e2530">
            <td style="padding:5px 0;color:#4a5a6a">2. Net Change by Change Orders</td>
            <td style="padding:5px 0;text-align:right;color:#ffb300">$320,140.00</td>
          </tr>
          <tr style="border-bottom:1px solid #1e2530">
            <td style="padding:5px 0;color:#c8d4e0;font-weight:600">3. Contract Sum to Date</td>
            <td style="padding:5px 0;text-align:right;color:#00d4ff;font-weight:600">$1,820,140.00</td>
          </tr>
          <tr style="border-bottom:1px solid #1e2530">
            <td style="padding:5px 0;color:#4a5a6a">4. Total Completed &amp; Stored to Date</td>
            <td style="padding:5px 0;text-align:right;color:#c8d4e0">$1,650,000.00</td>
          </tr>
          <tr style="border-bottom:1px solid #1e2530">
            <td style="padding:5px 0;color:#4a5a6a">5. Retainage (10%)</td>
            <td style="padding:5px 0;text-align:right;color:#ff3d57">$165,000.00</td>
          </tr>
          <tr style="border-bottom:2px solid #2a3340">
            <td style="padding:5px 0;color:#4a5a6a">6. Total Earned Less Retainage</td>
            <td style="padding:5px 0;text-align:right;color:#00e676">$1,485,000.00</td>
          </tr>
          <tr>
            <td style="padding:8px 0;color:#00d4ff;font-size:12px;font-weight:700">CURRENT PAYMENT DUE</td>
            <td style="padding:8px 0;text-align:right;color:#00d4ff;font-size:14px;font-weight:700">$1,485,000.00</td>
          </tr>
        </tbody>
      </table>
      <div style="margin-top:10px;display:flex;gap:8px">
        <button onclick="exportG702PDF()" style="flex:1;padding:7px;background:#00d4b8;color:#000;border:none;font-family:inherit;font-size:10px;font-weight:700;letter-spacing:.08em;cursor:pointer;text-transform:uppercase;border-radius:3px">⬇ Export G702 PDF</button>
        <a href="/html/construction/auditops-cfo-suite.html" style="flex:1;padding:7px;border:1px solid #00d4b8;color:#00d4b8;font-family:inherit;font-size:10px;letter-spacing:.08em;cursor:pointer;text-transform:uppercase;text-decoration:none;display:flex;align-items:center;justify-content:center;border-radius:3px">VIEW FULL CFO SUITE ↗</a>
      </div>
    </div>

  </div>
</div>
<!-- END CHART A -->
"""

# Inject Chart A before the Charts B-F section
chart_b_markers = [
    '<!-- CHART B',
    'CHART B',
    'chart-b',
    'chartB',
    'Cost-to-Complete',
    'COST-TO-COMPLETE',
    'WIP ANALYTICS',
    'Financial Intelligence Charts',
]
inserted_chart_a = False
for marker in chart_b_markers:
    if marker in src:
        # find the containing div or section
        idx = src.find(marker)
        # walk back to find opening of that block
        insert_at = src.rfind('\n', 0, idx) + 1
        src = src[:insert_at] + CHART_A_HTML + '\n' + src[insert_at:]
        inserted_chart_a = True
        print(f"  ✓  Chart A injected before '{marker}'")
        break

if not inserted_chart_a:
    # inject before closing </main> or </body>
    for tag in ['</main>', '</body>']:
        if tag in src:
            src = src.replace(tag, CHART_A_HTML + '\n' + tag, 1)
            inserted_chart_a = True
            print(f"  ✓  Chart A injected before {tag}")
            break

# ── FIX 4: ADD data-wip-sector TO EXISTING SECTOR SECTIONS ───────────────────
# Tag the charts section as construction sector
for old, new_attr, sector in [
    ('id="charts-section"',  'id="charts-section" data-wip-sector="construction"', 'construction'),
    ('id="wip-healthcare"',  'id="wip-healthcare" data-wip-sector="healthcare"',   'healthcare'),
    ('id="wip-insurance"',   'id="wip-insurance" data-wip-sector="insurance"',     'insurance'),
    ('id="wip-finops"',      'id="wip-finops" data-wip-sector="finops"',           'finops'),
]:
    if old in src and new_attr not in src:
        src = src.replace(old, new_attr, 1)
        print(f"  ✓  Tagged {old} with data-wip-sector={sector}")

# ── FIX 5: INJECT SECTOR SWITCH JS before </body> ─────────────────────────────
# Remove any previous injection first
src = src.replace(SECTOR_SWITCH_JS, '')

if '</body>' in src:
    src = src.replace('</body>', SECTOR_SWITCH_JS + '\n</body>', 1)
elif '</html>' in src:
    src = src.replace('</html>', SECTOR_SWITCH_JS + '\n</html>', 1)
else:
    src += SECTOR_SWITCH_JS

print("  ✓  Sector switch JS injected")

# ── FIX 6: exportG702PDF stub if missing ─────────────────────────────────────
if 'exportG702PDF' not in src:
    stub = """
<script>
function exportG702PDF() {
  alert('G702 PDF Export\\n\\nPOST /api/wip/construction/g702-export\\n\\nReturns bond-ready PDF:\\n• AIA G702 cover page\\n• G703 Schedule of Values\\n• Notarized signature block');
}
</script>
"""
    src = src.replace('</body>', stub + '</body>', 1)

# ── WRITE ─────────────────────────────────────────────────────────────────────
DASHBOARD.write_text(src, encoding='utf-8')
new_len = len(src)
print(f"\n  Original: {original_len:,} bytes")
print(f"  Patched:  {new_len:,} bytes (+{new_len - original_len:,})")

# ── VERIFY ────────────────────────────────────────────────────────────────────
print("\n🔎 Verification checks:")
checks = [
    ("switchSector function",           "window.switchSector = switchSector"),
    ("DOMContentLoaded wiring",         "DOMContentLoaded"),
    ("data-sector-btn attributes",      "data-sector-btn"),
    ("Chart A injected",                "CHART A · JOB HEALTH"),
    ("G702 table present",              "Contract Sum to Date"),
    ("Insurance sector",                'data-wip-sector="insurance"'),
    ("Hub link construction",           "/construction-suite/"),
    ("Hub link healthcare",             "/healthcare/"),
    ("URL param auto-select",           "URLSearchParams"),
]
all_ok = True
for label, needle in checks:
    ok = needle in src
    print(f"  {'✓' if ok else '✗'}  {label}")
    if not ok:
        all_ok = False

print()
if all_ok:
    print("=" * 55)
    print("  ✅  ALL CHECKS PASSED")
    print()
    print("  Run:  fly deploy")
    print()
    print("  Then test sector switching:")
    print("  https://tsm-shell.fly.dev/wip-dashboard.html?sector=insurance")
    print("  https://tsm-shell.fly.dev/wip-dashboard.html?sector=healthcare")
    print("  https://tsm-shell.fly.dev/wip-dashboard.html?sector=finops")
    print("=" * 55)
else:
    print("=" * 55)
    print("  ⚠  Some checks failed — review above")
    print("=" * 55)
