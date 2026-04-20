#!/usr/bin/env python3
import os, shutil

BASE = '/workspaces/tsm-shell'

# node -> line number where the script block starts (1-based, from grep output)
# We keep lines 1..(cut_line-1) and replace from cut_line onward
NODES = {
    'hc-billing':    117,
    'hc-insurance':  118,
    'hc-pharmacy':   116,
    'hc-legal':      119,
    'hc-vendors':    116,
    'hc-strategist': 118,
}

SYNC_MAP = {
    'hc-billing':    ['.fly-build/hc-billing/index.html',    'tmp_root/tsm-deploy/tsm-hc-billing/public/index.html'],
    'hc-insurance':  ['.fly-build/hc-insurance/index.html',  'tmp_root/tsm-deploy/tsm-hc-insurance/public/index.html'],
    'hc-pharmacy':   ['.fly-build/hc-pharmacy/index.html',   'tmp_root/tsm-deploy/tsm-hc-pharmacy/public/index.html'],
    'hc-legal':      ['.fly-build/hc-legal/index.html',      'tmp_root/tsm-deploy/tsm-hc-legal/public/index.html'],
    'hc-vendors':    ['.fly-build/hc-vendors/index.html',    'tmp_root/tsm-deploy/tsm-hc-vendors/public/index.html'],
    'hc-strategist': ['.fly-build/hc-strategist/index.html', 'tmp_root/tsm-deploy/tsm-hc-strategist/public/index.html'],
}

CLEAN_SCRIPT = '''<script>
(function () {

  function switchTab(id, btn) {
    document.querySelectorAll('[id^="tab-"]').forEach(function(el) {
      el.style.setProperty('display', 'none', 'important');
    });
    var target = document.getElementById('tab-' + id) || document.getElementById(id);
    if (target) target.style.setProperty('display', 'block', 'important');
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

print('=== TSM LINE-CUT FIX ===\n')
fixed = 0

for node, cut_line in NODES.items():
    path = os.path.join(BASE, 'html', node, 'index.html')
    if not os.path.exists(path):
        print(f'  MISSING {path}')
        continue

    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Verify the cut line looks right
    actual = lines[cut_line - 1].strip() if cut_line <= len(lines) else ''
    print(f'  {node}: cutting at line {cut_line} → {repr(actual[:60])}')

    shutil.copy2(path, path + '.bak')

    # Keep lines 1..(cut_line-2), drop the blank line before <script> too
    keep = lines[:cut_line - 2]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(''.join(keep) + '\n' + CLEAN_SCRIPT)

    fixed += 1

    for dest_rel in SYNC_MAP.get(node, []):
        dest = os.path.join(BASE, dest_rel)
        if os.path.exists(os.path.dirname(dest)):
            shutil.copy2(path, dest)
            print(f'    SYNC  → {dest_rel}')

print(f'\n=== DONE: {fixed}/{len(NODES)} files patched ===')
if fixed > 0:
    print('Run: fly deploy')
