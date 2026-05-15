#!/usr/bin/env python3
"""
Inject Chart A (Earned Value vs Contract vs Billed) into wip-dashboard.html
Run from /workspaces/tsm-shell:  python3 patch-chart-a.py
"""
import re, subprocess, shutil
from pathlib import Path

TARGET = Path('/workspaces/tsm-shell/html/wip-dashboard.html')

# ── Chart A HTML ─────────────────────────────────────────────────
CHART_A_HTML = """
    <!-- CHART A: Earned Value vs Contract vs Billed -->
    <div class="chart-card" style="margin-bottom:1rem">
      <div class="chart-head">
        <span class="chart-label" id="chartA-title">CHART A · EARNED VALUE vs CONTRACT vs BILLED-TO-DATE</span>
        <span class="chart-sub">Over / Under Billing Position — All Active Entities</span>
      </div>
      <div class="chart-body">
        <canvas id="chartA" height="160"></canvas>
        <div class="chart-insight" id="insightA"><strong>Loading…</strong></div>
      </div>
    </div>
"""

# ── Chart A Data for all 4 sectors ───────────────────────────────
CHART_A_DATA = """
  finops: {
    A: {
      labels: ['AP-WEST', 'AP-ACME', 'AR-DELTA', 'RECON-001', 'AR-SUN'],
      contract:[18400, 14200, 12200, 48000, 8600],
      earned:  [2760,   710,  4880,  9600, 6880],
      billed:  [0,        0,     0,     0,     0],
      insight: '<strong>All FinOps entities under-billed or unresolved.</strong> $48K bank variance has $0 collected. Westside Holdings ($18.4K) and Acme Supply ($14.2K) both at 0% resolution. Immediate escalation required across all 5 positions.',
    },
  },
"""

CHART_A_SECTOR_DATA = {
    'construction': {
        'labels': "['JOB-203','JOB-198','JOB-211','JOB-187','JOB-215']",
        'contract': "[1820000, 3100000, 2300000, 4200000, 900000]",
        'earned':   "[1148600, 2728000,  943000, 4074000, 198000]",
        'billed':   "[1760000, 3150000, 2100000, 4220000, 850000]",
        'insight':  "'<strong>JOB-211 critical over-billed:</strong> Billed $2.1M against $943K earned — $1.16M overbilling risk. JOB-203 under-billed $60K. JOB-187 near complete and on target. Portfolio net position: -$110K under-billed excluding JOB-211 risk.'",
    },
    'healthcare': {
        'labels': "['ENC-8821','ENC-8834','ENC-8756','ENC-8801','ENC-8912']",
        'contract': "[4200, 1850, 6100, 3300, 2750]",
        'earned':   "[3570, 1110, 5490, 3300,  825]",
        'billed':   "[0,    1480, 5490, 3300,    0]",
        'insight':  "'<strong>ENC-8821 and ENC-8912 show zero collection</strong> against earned revenue. ENC-8821: $3,570 earned, $0 collected — appeal required. ENC-8912: $825 earned, $0 collected — scrubbing hold blocking billing. Total uncollected earned: $4,395.'",
    },
    'insurance': {
        'labels': "['CLM-882','CLM-841','CLM-901','CLM-867','CLM-923']",
        'contract': "[85000, 124000, 210000, 340000, 840000]",
        'earned':   "[34000, 117800,  52500, 265200, 504000]",
        'billed':   "[63750, 120000, 157500, 332000, 504000]",
        'insight':  "'<strong>CLM-882 over-reserved:</strong> Paid $63.75K against $34K liability established — $29.75K excess. CLM-901 paid $157.5K against $52.5K established — $105K over-reserved, release candidate. CLM-923 at $504K paid, fraud flag active — freeze all further payments.'",
    },
}

CHART_A_JS = """
// ── CHART A DATA ─────────────────────────────────────────────────
const CHART_A_DATA = {
  construction: {
    labels:   ['JOB-203','JOB-198','JOB-211','JOB-187','JOB-215'],
    contract: [1820000, 3100000, 2300000, 4200000, 900000],
    earned:   [1148600, 2728000,  943000, 4074000, 198000],
    billed:   [1760000, 3150000, 2100000, 4220000, 850000],
    insight:  '<strong>JOB-211 critical over-billed:</strong> Billed $2.1M against $943K earned — $1.16M overbilling risk. JOB-203 under-billed $60K. JOB-187 near complete on target. Portfolio net: -$110K under-billed excluding JOB-211 risk.',
  },
  healthcare: {
    labels:   ['ENC-8821','ENC-8834','ENC-8756','ENC-8801','ENC-8912'],
    contract: [4200, 1850, 6100, 3300, 2750],
    earned:   [3570, 1110, 5490, 3300,  825],
    billed:   [0,    1480, 5490, 3300,    0],
    insight:  '<strong>ENC-8821 and ENC-8912 show zero collection</strong> against earned revenue. ENC-8821: $3,570 earned, $0 collected — appeal required. ENC-8912: $825 earned, $0 billed — scrubbing hold. Total uncollected earned: $4,395.',
  },
  insurance: {
    labels:   ['CLM-882','CLM-841','CLM-901','CLM-867','CLM-923'],
    contract: [85000, 124000, 210000, 340000, 840000],
    earned:   [34000, 117800,  52500, 265200, 504000],
    billed:   [63750, 120000, 157500, 332000, 504000],
    insight:  '<strong>CLM-882 over-reserved:</strong> Paid $63.75K against $34K liability — $29.75K excess. CLM-901 over-reserved by $105K — release candidate. CLM-923 at $504K paid — fraud flag active, freeze all further payments.',
  },
  finops: {
    labels:   ['WEST-AR','ACME-AP','DELTA-AR','RECON','SUN-AR'],
    contract: [18400, 14200, 12200, 48000, 8600],
    earned:   [2760,    710,  4880,  9600, 6880],
    billed:   [0,         0,     0,     0,     0],
    insight:  '<strong>All FinOps positions show zero resolution.</strong> $48K bank variance unresolved. Westside Holdings and Acme Supply both at 0% collection. Total exposure: $83,400. Month-end close at risk without immediate action on all 5 positions.',
  },
};

let _cA = null;

function renderChartA(sector) {
  const d = CHART_A_DATA[sector] || CHART_A_DATA.construction;
  const c = CHART_COLORS[sector] || CHART_COLORS.construction;
  const gridColor = 'rgba(255,255,255,0.04)';
  const tickColor = 'rgba(255,255,255,0.25)';
  const fontMono  = 'JetBrains Mono';

  if (_cA) _cA.destroy();
  _cA = new Chart(document.getElementById('chartA'), {
    type: 'bar',
    data: {
      labels: d.labels,
      datasets: [
        {
          label: 'Contract / Reserve Value',
          data: d.contract,
          backgroundColor: 'rgba(255,255,255,0.06)',
          borderColor: 'rgba(255,255,255,0.2)',
          borderWidth: 1,
        },
        {
          label: 'Earned / Established',
          data: d.earned,
          backgroundColor: c.primary + '55',
          borderColor: c.primary,
          borderWidth: 1.5,
        },
        {
          label: 'Billed / Collected',
          data: d.billed,
          backgroundColor: 'rgba(0,229,255,0.3)',
          borderColor: '#00e5ff',
          borderWidth: 1.5,
        },
      ],
    },
    options: {
      responsive: true,
      animation: { duration: 600 },
      plugins: {
        legend: { labels: { color: tickColor, font: { family: fontMono, size: 9 }, boxWidth: 10 } },
        tooltip: {
          callbacks: {
            label: ctx => {
              const v = ctx.parsed.y;
              return ctx.dataset.label + ': ' + (v >= 1000 ? '$' + (v/1000).toFixed(0) + 'K' : '$' + v.toLocaleString());
            }
          }
        }
      },
      scales: {
        x: { grid: { color: gridColor }, ticks: { color: tickColor, font: { family: fontMono, size: 8 } } },
        y: {
          grid: { color: gridColor },
          ticks: {
            color: tickColor,
            font: { family: fontMono, size: 8 },
            callback: v => v >= 1000000 ? '$' + (v/1000000).toFixed(1) + 'M' : v >= 1000 ? '$' + (v/1000).toFixed(0) + 'K' : '$' + v
          }
        },
      },
    },
  });
  document.getElementById('insightA').innerHTML = d.insight;
}

// Hook into sector switcher
const __origSetSectorChartA = window.setSector;
window.setSector = function(s) {
  __origSetSectorChartA(s);
  renderChartA(s);
};

// Init
if (document.readyState !== 'loading') renderChartA('construction');
else document.addEventListener('DOMContentLoaded', () => renderChartA('construction'));
"""

def main():
    src = TARGET.read_text(encoding='utf-8')
    
    if 'chartA' in src:
        print('Chart A already present — removing old version first')
        src = re.sub(r'<!-- CHART A:.*?</div>\s*</div>\s*', '', src, flags=re.DOTALL)

    # Back up
    bak = TARGET.with_suffix('.html.bak.chart-a')
    if not bak.exists():
        shutil.copy2(TARGET, bak)

    # Inject Chart A HTML before "// WIP ANALYTICS · CHARTS B–F"
    anchor_html = '<!-- ═══ CHARTS B-F'
    if anchor_html in src:
        src = src.replace(anchor_html, CHART_A_HTML + '\n' + anchor_html, 1)
        print('✔ Chart A HTML injected before Charts B-F')
    else:
        # fallback: inject before charts-section div
        src = src.replace('<div class="charts-section"', CHART_A_HTML + '\n<div class="charts-section"', 1)
        print('✔ Chart A HTML injected (fallback)')

    # Inject Chart A JS before </body>
    if 'CHART_A_DATA' not in src:
        src = src.replace('</body>', f'<script id="tsm-chart-a">\n{CHART_A_JS}\n</script>\n</body>', 1)
        print('✔ Chart A JS injected')

    TARGET.write_text(src, encoding='utf-8')

    # Validate
    scripts = re.findall(r'<script[^>]*>(.*?)</script>', src, re.DOTALL)
    biggest = max(scripts, key=len)
    open('/tmp/t.js', 'w').write(biggest)
    r = subprocess.run(['node', '--check', '/tmp/t.js'], capture_output=True, text=True)
    print('JS:', '✔ OK' if r.returncode == 0 else 'ERROR: ' + r.stderr[:300])
    print('\nRun: fly deploy')

if __name__ == '__main__':
    main()
