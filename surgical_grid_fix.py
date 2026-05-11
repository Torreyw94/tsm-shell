import os

path = './html/finops-suite/financial-ui.html'
with open(path, 'r') as f:
    html = f.read()

# 1. CLEANUP: Remove the "Nuclear" overlaps and duplicated blocks
import re
# Remove all instances of the messed up Node 08 we just injected
html = re.sub(r'<div[^>]*id="node-08".*?</div>', '', html, flags=re.DOTALL)
# Remove the forced styles we added
html = re.sub(r'<style>\s*#node-08.*?</style>', '', html, flags=re.DOTALL)

# 2. DEFINE THE CLEAN CARD: Matches your existing green/black theme exactly
clean_node_08 = """
      <div class="mod-card" id="node-08" onclick="window.location.href='finops-showcase-v2.html'" style="cursor:pointer; border-top: 1px solid #1a3a3a;">
        <div class="mod-num"><span class="mod-num-n">08</span> · Multi-Engine Triage</div>
        <div class="mod-title">ACCOUNTING DOC POC</div>
        <div class="mod-subtitle">INGEST · PARSE · ANALYSIS</div>
        <div class="mod-desc">Simultaneously runs Entity, Ledger, Anomaly, and Risk nodes for automated bank reconciliation.</div>
        <div class="mod-metrics">
          <span class="metric hot">OCR ACTIVE</span>
          <span class="metric warn">4-ENGINE</span>
        </div>
        <button class="mod-btn">OPEN SHOWCASE →</button>
      </div>
"""

# 3. INSERTION: Place it at the end of the main grid container
if '' in html:
    html = html.replace('', '\n' + clean_node_08)
else:
    # Fallback to appending before the grid closes
    html = html.replace('</div>', clean_node_08 + '\n</div>')

with open(path, 'w') as f:
    f.write(html)
print("UI Restored: Node 08 integrated into grid.")
