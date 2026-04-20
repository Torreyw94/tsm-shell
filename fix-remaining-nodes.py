#!/usr/bin/env python3
import os, re, shutil

BASE = '/workspaces/tsm-shell'

NODES = [
    'hc-billing',
    'hc-insurance',
    'hc-pharmacy',
    'hc-legal',
    'hc-vendors',
    'hc-grants',
    'hc-strategist',
]

# The clean Q() + switchTab to inject — replaces everything from the
# last <script> block before </body> that contains switchTab/Q/fetch
CLEAN_SCRIPT = '''<script>
(function () {

  function switchTab(id, btn) {
    document.querySelectorAll('[id^="tab-"]').forEach(function(el) {
      el.style.setProperty('display', 'none', 'important');
    });
    var target = document.getElementById('tab-' + id) || document.getElementById(id);
    if (target) target.style.setProperty('display', 'block', 'important');
    document.querySelectorAll('.tab').forEach(function(b) { b.classList.remove('act'); });
    var tabBtn = document.getElementById('t-' + id);
    if (tabBtn) tabBtn.classList.add('act');
    document.querySelectorAll('.nav-btn').forEach(function(b) { b.classList.remove('active'); });
    if (btn) btn.classList.add('active');
  }

  function showTab(id) { switchTab(id, null); }

  function loadAI(prompt) {
    var aiBtn = null;
    document.querySelectorAll('.nav-btn').forEach(function(b) {
      if ((b.getAttribute('onclick') || '').indexOf("'ai'") > -1) aiBtn = b;
    });
    switchTab('ai', aiBtn);
    var inp = document.getElementById('ai-inp');
    if (inp) { inp.value = prompt; inp.focus(); }
    setTimeout(function() { Q(prompt, 'ai-btn', 'ai-res'); }, 50);
  }

  function loadPreset(p) { loadAI(p); }

  window.Q = async function(prompt, btnId, resId) {
    if (!prompt || !prompt.trim()) return;
    var btn = document.getElementById(btnId);
    var res = document.getElementById(resId);
    if (!btn || !res) return;
    btn.disabled = true;
    res.innerHTML = '<span style="display:inline-block;animation:spin 1s linear infinite">&#x27F3;</span> TSM Neural processing...';
    if (res.classList) res.classList.add('show');
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
      if (res.classList) res.classList.remove('show');
      res.textContent = 'TSM NEURAL ERROR: ' + e.message;
    }
    btn.disabled = false;
  };

  window.switchTab  = switchTab;
  window.showTab    = showTab;
  window.loadAI     = loadAI;
  window.loadPreset = loadPreset;

  window.addEventListener('load', function() {
    setTimeout(function() {
      var first = document.querySelector('.nav-btn');
      if (first) {
        var m = (first.getAttribute('onclick') || '').match(/switchTab\\('([^']+)'/);
        switchTab(m ? m[1] : 'dash', first);
        console.log('\\u2714 TSM Tab Engine booted');
      }
    }, 60);
  });

})();
</script>
</body></html>'''

# For hc-grants the ending is different — it ends after the intake poll script
# We cut at the last <script> block that contains switchTab OR fetch groq OR Q(prompt
def find_cut(content):
    # Strategy: find the LAST <script> tag that contains our tab/AI logic
    # Look for last occurrence of these patterns
    candidates = []

    for marker in [
        '\n<script>\nasync function Q(',
        '\n<script>\nfunction switchTab(',
        '\n<script>\n(function () {\n  function switchTab',
        '\n<script>\nwindow.switchTab',
        # hc-grants ends differently — cut before the last </script></body></html>
        '\nasync function pollHc',
    ]:
        idx = content.rfind(marker)  # rfind = LAST occurrence
        if idx != -1:
            candidates.append(idx)

    if not candidates:
        return -1
    return min(candidates)  # earliest of the last occurrences = start of the final script block

print('=== TSM Q() PROXY FIX ===\n')
fixed = 0

SYNC_MAP = {
    'hc-billing':    ['.fly-build/hc-billing/index.html',    'tmp_root/tsm-deploy/tsm-hc-billing/public/index.html'],
    'hc-insurance':  ['.fly-build/hc-insurance/index.html',  'tmp_root/tsm-deploy/tsm-hc-insurance/public/index.html'],
    'hc-pharmacy':   ['.fly-build/hc-pharmacy/index.html',   'tmp_root/tsm-deploy/tsm-hc-pharmacy/public/index.html'],
    'hc-legal':      ['.fly-build/hc-legal/index.html',      'tmp_root/tsm-deploy/tsm-hc-legal/public/index.html'],
    'hc-vendors':    ['.fly-build/hc-vendors/index.html',    'tmp_root/tsm-deploy/tsm-hc-vendors/public/index.html'],
    'hc-grants':     ['.fly-build/hc-grants/index.html',     'tmp_root/tsm-deploy/tsm-hc-grants/public/index.html'],
    'hc-strategist': ['.fly-build/hc-strategist/index.html', 'tmp_root/tsm-deploy/tsm-hc-strategist/public/index.html'],
}

for node in NODES:
    path = os.path.join(BASE, 'html', node, 'index.html')
    if not os.path.exists(path):
        print(f'  MISSING {path}')
        continue

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Skip if already using proxy
    if '/api/groq' in content:
        print(f'  ALREADY PATCHED {node} — skipping')
        continue

    cut = find_cut(content)
    if cut == -1:
        print(f'  SKIP {node} — no cut point found')
        continue

    shutil.copy2(path, path + '.bak')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content[:cut] + '\n' + CLEAN_SCRIPT)

    print(f'  FIXED {node}')
    fixed += 1

    for dest_rel in SYNC_MAP.get(node, []):
        dest = os.path.join(BASE, dest_rel)
        if os.path.exists(os.path.dirname(dest)):
            shutil.copy2(path, dest)
            print(f'    SYNC  → {dest_rel}')

print(f'\n=== DONE: {fixed}/{len(NODES)} files patched ===')
if fixed > 0:
    print('Run: fly deploy')
