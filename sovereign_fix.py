import os
import time

path = './html/finops-suite/financial-ui.html'
with open(path, 'r') as f:
    html = f.read()

# 1. CACHE BUSTER & SERVICE WORKER KILLER
# This script ensures the browser doesn't try to be "smart" with old versions
cache_killer = f"""
<script>
// Clear any rogue service workers
if ('serviceWorker' in navigator) {{
    navigator.serviceWorker.getRegistrations().then(regs => {{
        for(let reg of regs) reg.unregister();
    }});
}}

// Global Force-Nav function
window.forceNav = function(target) {{
    console.log("Sovereign Link: Forcing jump to " + target);
    window.location.href = target + '?v={int(time.time())}';
}};
</script>
"""

# 2. OVERLAY INJECTION
# We replace the static divs with high-priority "Action Zones"
html = html.replace('id="node-05"', 'id="node-05" onclick="window.forceNav(\'compliance.html\')" style="cursor:pointer !important; border: 1px solid #5dba3b !important;"')
html = html.replace('id="node-08"', 'id="node-08" onclick="window.forceNav(\'finops-showcase-v2.html\')" style="cursor:pointer !important; border: 1px solid #f5a623 !important;"')

if '</head>' in html:
    html = html.replace('</head>', cache_killer + '</head>')

with open(path, 'w') as f:
    f.write(html)
