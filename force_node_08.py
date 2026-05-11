import os

path = './html/finops-suite/financial-ui.html'
with open(path, 'r') as f:
    html = f.read()

# 1. Surgical CSS injection to ensure the second row is visible
force_css = """
<style>
  .mod-grid { display: grid !important; grid-template-columns: repeat(auto-fill, minmax(300px, 1r)) !important; gap: 20px !important; height: auto !important; overflow: visible !important; }
  #node-08 { border: 2px solid #f5a623 !important; display: block !important; visibility: visible !important; }
</style>
"""

# 2. The Node 08 Card with absolute pathing
node_08_card = """
<div class="mod-card" id="node-08" onclick="window.location.href='/finops-suite/finops-showcase-v2.html'" style="cursor:pointer;">
  <div class="mod-num"><span class="mod-num-n">08</span> · Multi-Engine Triage</div>
  <div class="mod-title">Accounting DOC POC</div>
  <div class="mod-subtitle">Ingest · Parse · Analysis</div>
  <div class="mod-desc">High-speed extraction engine for bank reconciliations. Simultaneously runs Entity, Ledger, Anomaly, and Risk nodes.</div>
  <div class="mod-metrics">
    <span class="metric hot">OCR Active</span>
    <span class="metric" style="background: rgba(245, 166, 35, 0.1); color: #f5a623;">4-Engine Showcase</span>
  </div>
  <button class="mod-btn">Open Showcase →</button>
</div>
"""

# Inject CSS at top and Card at bottom of the mod-grid
if '</head>' in html:
    html = html.replace('</head>', force_css + '</head>')

if '</div>' in html:
    html = html.replace('</div>', node_08_card + '</div>')
elif '</div>\n  </main>' in html:
    html = html.replace('</div>\n  </main>', node_08_card + '</div>\n  </main>')

with open(path, 'w') as f:
    f.write(html)
