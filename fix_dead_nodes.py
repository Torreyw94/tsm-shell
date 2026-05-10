import os

path = './html/finops-suite/financial-ui.html'
with open(path, 'r') as f:
    html = f.read()

# 1. Physical Attribute Injection
# We force the cursor to change and add a direct window.location 
# to the divs themselves, bypassing any broken global scripts.
html = html.replace('id="node-05"', 'id="node-05" style="cursor:pointer !important;" onclick="window.location.href=\'compliance.html\';"')
html = html.replace('id="node-08"', 'id="node-08" style="cursor:pointer !important;" onclick="window.location.href=\'finops-showcase-v2.html\';"')

# 2. The "Nuclear" Event Listener
# This script runs at the very bottom of the page and "hijacks" 
# any click on those two boxes regardless of what else is breaking.
nuclear_script = """
<script>
window.addEventListener('mousedown', function(e) {
    const card05 = e.target.closest('#node-05');
    const card08 = e.target.closest('#node-08');
    
    if (card05) {
        console.log("Forcing Navigation to Compliance...");
        window.location.href = 'compliance.html';
    }
    if (card08) {
        console.log("Forcing Navigation to Showcase...");
        window.location.href = 'finops-showcase-v2.html';
    }
}, true); // The 'true' here is key—it captures the click before any other script can stop it.
</script>
"""

if '</body>' in html:
    html = html.replace('</body>', nuclear_script + '</body>')

with open(path, 'w') as f:
    f.write(html)
