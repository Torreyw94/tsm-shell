file_path = './html/finops-suite/financial-ui.html'
with open(file_path, 'r') as f:
    html = f.read()

override = """
<script>
// Kill the legacy redirect function
window.go = function() { return false; };

function runFinOpsAudit(element) {
    console.log("TSM_SHIELD: FinOps Redirect Blocked. Analyzing...");
    const moduleName = element.querySelector('h3')?.innerText || "FinOps Module";
    
    // Update the Intelligence Feed without changing the page
    const feed = document.querySelector('.intelligence-feed');
    if (feed) {
        feed.innerHTML = `[STRATEGIST] Analyzing ${moduleName}... <span class='loading'></span>`;
        // Trigger your established Neural Link
        if (window.tsmInstance) window.tsmInstance.runAudit("Accounting", moduleName);
    }
    return false;
}
</script>
"""

if '</body>' in html:
    new_html = html.replace('</body>', override + '</body>')
    with open(file_path, 'w') as f:
        f.write(new_html)
