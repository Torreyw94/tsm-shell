#!/usr/bin/env python3
import os, shutil

BASE = '/workspaces/tsm-shell'

NODES = [
    'hc-billing',
    'hc-insurance',
    'hc-pharmacy',
    'hc-legal',
    'hc-vendors',
    'hc-strategist',
]

SYNC_MAP = {
    'hc-billing':    ['.fly-build/hc-billing/index.html',    'tmp_root/tsm-deploy/tsm-hc-billing/public/index.html'],
    'hc-insurance':  ['.fly-build/hc-insurance/index.html',  'tmp_root/tsm-deploy/tsm-hc-insurance/public/index.html'],
    'hc-pharmacy':   ['.fly-build/hc-pharmacy/index.html',   'tmp_root/tsm-deploy/tsm-hc-pharmacy/public/index.html'],
    'hc-legal':      ['.fly-build/hc-legal/index.html',      'tmp_root/tsm-deploy/tsm-hc-legal/public/index.html'],
    'hc-vendors':    ['.fly-build/hc-vendors/index.html',    'tmp_root/tsm-deploy/tsm-hc-vendors/public/index.html'],
    'hc-strategist': ['.fly-build/hc-strategist/index.html', 'tmp_root/tsm-deploy/tsm-hc-strategist/public/index.html'],
}

# Insert Q() just before </script></body></html>
# We replace the closing tags with Q() + closing tags
OLD_TAIL = '</script>\n</body></html>'
OLD_TAIL_ALT = '</script>\n</body></html>'

Q_INJECT = '''
  // ── GROQ via /api/groq proxy ──
  window.Q = async function(prompt, btnId, resId) {
    if (!prompt || !prompt.trim()) return;
    var btn = document.getElementById(btnId);
    var res = document.getElementById(resId);
    if (!btn || !res) return;
    btn.disabled = true;
    res.innerHTML = '<span style="display:inline-block;animation:spin 1s linear infinite">&#x27F3;</span> TSM Neural processing...';
    try {
      var r = await fetch('/api/groq', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: prompt })
      });
      if (!r.ok) { var e = await r.text(); throw new Error('HTTP ' + r.status + ': ' + e); }
      var d = await r.json();
      if (d.error) throw new Error(d.error);
      res.style.whiteSpace = 'pre-wrap';
      res.textContent = '> TSM NEURAL [' + new Date().toLocaleTimeString() + ']\\n\\n' + d.reply.trim();
    } catch(e) {
      res.textContent = 'TSM NEURAL ERROR: ' + e.message;
    }
    btn.disabled = false;
  };
</script>
</body></html>'''

print('=== TSM Q() INJECT ===\n')
fixed = 0

for node in NODES:
    path = os.path.join(BASE, 'html', node, 'index.html')
    if not os.path.exists(path):
        print(f'  MISSING {path}')
        continue

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    if '/api/groq' in content:
        print(f'  SKIP {node} — already has proxy')
        continue

    # Find last </script></body></html> and inject Q() before it closes
    # The file ends with: });↵</script>↵</body></html>
    cut = content.rfind('\n</script>\n</body></html>')
    if cut == -1:
        cut = content.rfind('</script>\n</body></html>')
    if cut == -1:
        cut = content.rfind('</script></body></html>')

    if cut == -1:
        print(f'  ERROR: cannot find closing tag in {node}')
        continue

    shutil.copy2(path, path + '.bak2')

    # Keep everything up to (not including) the closing </script>
    # then inject Q() and close
    new_content = content[:cut] + Q_INJECT

    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f'  FIXED {node} — Q() injected')
    fixed += 1

    for dest_rel in SYNC_MAP.get(node, []):
        dest = os.path.join(BASE, dest_rel)
        if os.path.exists(os.path.dirname(dest)):
            shutil.copy2(path, dest)
            print(f'    SYNC → {dest_rel}')

print(f'\n=== DONE: {fixed}/{len(NODES)} fixed ===')
if fixed > 0:
    print('Run: fly deploy')
