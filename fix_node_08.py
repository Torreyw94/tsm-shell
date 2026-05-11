import os

path = './html/finops-suite/financial-ui.html'
with open(path, 'r') as f:
    html = f.read()

# This is the "Showcase V2" card styled to match your existing grid
node_08_card = """
      <div class="mod-card" id="node-08" onclick="window.location.href='finops-showcase-v2.html'" style="cursor:pointer; border-left: 4px solid #f5a623;">
        <div class="mod-num"><span class="mod-num-n">08</span> · Multi-Engine Triage</div>
        <div class="mod-title">Accounting DOC POC</div>
        <div class="mod-subtitle">Ingest · Parse · Analysis</div>
        <div class="mod-desc">The high-speed extraction engine for bank reconciliations and GL extracts. Processes data through Entity, Ledger, Anomaly, and Risk nodes.</div>
        <div class="mod-metrics">
          <span class="metric hot">4-Engine Active</span>
          <span class="metric" style="background: rgba(245, 166, 35, 0.1); color: #f5a623;">Showcase V2</span>
        </div>
        <button class="mod-btn">Launch Showcase →</button>
      </div>
"""

# If Node 07 exists, we place Node 08 immediately after it
if 'id="node-07"' in html:
    # We find the end of the Node 07 div and inject 08
    parts = html.split('')
    if len(parts) > 1:
        html = parts[0] + '' + node_08_card + parts[1]
    else:
        # Fallback: find the last mod-card and append
        html = html.replace('</div>\n    </div>\n  </main>', node_08_card + '</div>\n    </div>\n  </main>')

with open(path, 'w') as f:
    f.write(html)
