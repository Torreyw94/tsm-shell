import os

path = './html/finops-suite/financial-ui.html'
with open(path, 'r') as f:
    html = f.read()

# The New Node 08 HTML
node_08_html = """
<div class="mod-card" id="node-08" onclick="window.location.href='finops-showcase-v2.html'" style="cursor:pointer; border-left: 4px solid #f5a623;">
  <div class="mod-num"><span class="mod-num-n">08</span> · Real-time Triage</div>
  <div class="mod-title">Accounting DOC POC</div>
  <div class="mod-subtitle">Multi-Engine Extraction</div>
  <div class="mod-desc">Automated extraction and structural processing. Simultaneously runs Entity, Ledger, Anomaly, and Risk engines for high-speed document ingest.</div>
  <div class="mod-metrics"><span class="metric hot">OCR Active</span><span class="metric" style="background: rgba(245, 166, 35, 0.1); color: #f5a623;">4x Parallel Engine</span></div>
  <button class="mod-btn">Launch Showcase →</button>
</div>
"""

# Replace the existing node-08 block
import re
html = re.sub(r'<div[^>]*id="node-08".*?</div>\s*</div>', node_08_html, html, flags=re.DOTALL)

with open(path, 'w') as f:
    f.write(html)
