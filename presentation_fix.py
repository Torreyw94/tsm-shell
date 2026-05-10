import os

ui_path = './html/finops-suite/financial-ui.html'
showcase_path = './html/finops-suite/finops-showcase-v2.html'

def fix_file(path, is_main_ui=True):
    if not os.path.exists(path): return
    with open(path, 'r') as f:
        html = f.read()

    # 1. PURGE DUPLICATES (Clean slate for Library)
    lines = html.splitlines()
    html = "\n".join([l for l in lines if not any(w in l for w in ["LIBRARY", "Sample Audits", "Playbook"])])

    # 2. INJECT PERSISTENT SIDEBAR (presentation style)
    sidebar_html = """
    <div class="sidebar-block" style="margin-top: 30px; border-top: 1px solid #1a3a3a; padding-top: 20px;">
        <h3 style="color: #5dba3b; font-size: 0.75rem; letter-spacing: 2px; margin-bottom: 15px;">LIBRARY</h3>
        <button class="guide-btn" onclick="document.getElementById('search-bar').value='auditops \\\"Mesa Premier Legal\\\" --logic=strategist'" style="width:100%; margin-bottom: 8px; background: #121818; border: 1px solid #252d2d; color: #888; padding: 10px; cursor: pointer; text-align: left;">Sample Audits</button>
        <button class="guide-btn" style="width:100%; background: #121818; border: 1px solid #252d2d; color: #888; padding: 10px; cursor: pointer; text-align: left;">Playbook</button>
    </div>
    """
    if '</aside>' in html:
        html = html.replace('</aside>', sidebar_html + '</aside>')

    if is_main_ui:
        # 3. BULLETPROOF NODE WIRING (04-08)
        # We use a 'Shield' approach to ensure clicks always fire
        mappings = {
            'node-04': 'tax.html',
            'node-05': 'compliance.html',
            'node-06': 'zero-trust.html',
            'node-07': 'finops-operations.html',
            'node-08': 'finops-showcase-v2.html'
        }
        for node_id, target in mappings.items():
            # Force high-priority onclick and cursor
            html = html.replace(f'id="{node_id}"', f'id="{node_id}" style="cursor:pointer!important; z-index:99!important;" onclick="window.location.href=\'{target}\'"')

    with open(path, 'w') as f:
        f.write(html)

fix_file(ui_path, True)
fix_file(showcase_path, False)
print("Wiring finalized for presentation.")
