import os

path = './html/finops-suite/financial-ui.html'
with open(path, 'r') as f:
    html = f.read()

# 1. Surgical Cleanup
import re
# Remove any raw text duplicates of Library/Sample/Playbook
lines = html.splitlines()
html = "\n".join([l for l in lines if not any(w in l for w in ["LIBRARY", "Sample Audits", "Playbook"])])

# 2. Sidebar Restoration (Single, Styled Copy)
library_section = """
<div class="sidebar-block" style="margin-top: 30px; border-top: 1px solid #1a3a3a; padding-top: 20px;">
    <h3 style="color: #5dba3b; font-size: 0.75rem; letter-spacing: 2px; margin-bottom: 15px;">LIBRARY</h3>
    <button class="guide-btn" onclick="document.getElementById('search-bar').value='auditops \\\"Mesa Premier Legal\\\" --logic=strategist'" style="width:100%; margin-bottom: 8px; background: #121818; border: 1px solid #252d2d; color: #888; padding: 10px; cursor: pointer; text-align: left;">Sample Audits</button>
    <button class="guide-btn" style="width:100%; background: #121818; border: 1px solid #252d2d; color: #888; padding: 10px; cursor: pointer; text-align: left;">Playbook</button>
</div>
"""
if '</aside>' in html:
    html = html.replace('</aside>', library_section + '</aside>')

# 3. The 05/08 "Un-Sticker"
# We wrap the card content in a high-priority link and force pointer events
html = html.replace('id="node-05"', 'id="node-05" style="cursor:pointer !important; z-index:99!important; pointer-events:auto!important;" onclick="window.location.href=\'compliance.html\'"')
html = html.replace('id="node-08"', 'id="node-08" style="cursor:pointer !important; z-index:99!important; pointer-events:auto!important;" onclick="window.location.href=\'finops-showcase-v2.html\'"')

# 4. Wiring the rest of Row 2
html = html.replace('go(TARGET_04)', "location.href='tax.html'")
html = html.replace('go(TARGET_06)', "location.href='zero-trust.html'")
html = html.replace('go(TARGET_07)', "location.href='finops-operations.html'")

with open(path, 'w') as f:
    f.write(html)
