file_path = './html/finops-suite/financial-ui.html'
with open(file_path, 'r') as f:
    content = f.read()

binding_script = """
<script>
document.addEventListener('DOMContentLoaded', () => {
    const nodes = ['node-05', 'node-08'];
    nodes.forEach(id => {
        const el = document.getElementById(id);
        if (el) {
            el.style.cursor = 'pointer';
            el.onclick = function(e) {
                e.preventDefault();
                const module = this.getAttribute('data-module') || "FinOps Module";
                console.log("Strategist: Activating " + module);
                
                // Update Feed UI
                const feed = document.querySelector('.intelligence-feed');
                if (feed) {
                    feed.innerHTML = `[STRATEGIST] <span style="color: #00ff00;">●</span> Executing ${module} Audit...`;
                }
                
                // Trigger Neural Link
                if (window.tsmInstance) {
                    window.tsmInstance.runAudit("FinOps", module);
                }
            };
        }
    });
});
</script>
"""

if '</body>' in content:
    new_content = content.replace('</body>', binding_script + '</body>')
    with open(file_path, 'w') as f:
        f.write(new_content)
