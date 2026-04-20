#!/usr/bin/env python3
import os, shutil, re

BASE = '/workspaces/tsm-shell'

NODES = [
    'hc-billing',
    'hc-insurance',
    'hc-pharmacy',
    'hc-legal',
    'hc-vendors',
    'hc-strategist',
    'hc-grants',
    'hc-medical',
]

SYNC_MAP = {
    'hc-billing':    ['.fly-build/hc-billing/index.html',    'tmp_root/tsm-deploy/tsm-hc-billing/public/index.html'],
    'hc-insurance':  ['.fly-build/hc-insurance/index.html',  'tmp_root/tsm-deploy/tsm-hc-insurance/public/index.html'],
    'hc-pharmacy':   ['.fly-build/hc-pharmacy/index.html',   'tmp_root/tsm-deploy/tsm-hc-pharmacy/public/index.html'],
    'hc-legal':      ['.fly-build/hc-legal/index.html',      'tmp_root/tsm-deploy/tsm-hc-legal/public/index.html'],
    'hc-vendors':    ['.fly-build/hc-vendors/index.html',    'tmp_root/tsm-deploy/tsm-hc-vendors/public/index.html'],
    'hc-strategist': ['.fly-build/hc-strategist/index.html', 'tmp_root/tsm-deploy/tsm-hc-strategist/public/index.html'],
    'hc-grants':     ['.fly-build/hc-grants/index.html',     'tmp_root/tsm-deploy/tsm-hc-grants/public/index.html'],
    'hc-medical':    ['.fly-build/hc-medical/index.html',    'tmp_root/tsm-deploy/tsm-hc-medical/public/index.html'],
}

CLEAN_SCRIPT = '''\n<script>
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

# Patterns to find the LAST script block — search from end of file
# We want the last <script> tag that starts the tab/AI engine
CUT_PATTERNS = [
    # Exact string that appears right before the script block we want to replace
    '\n<script>\nfunction switchTab(id, btn) {',
    '\n<script>\nasync function Q(',
    '\n<script>\n(function () {\n  function switchTab',
    '\n<script id="tsm-',
    '\n<script>\n// Honor Portal tab fix',
    # For hc-grants/hc-medical which have extra scripts before the tab engine
    '\nasync function pollHc',
]

print('=== TSM RESTORE + REFIX ===\n')
fixed = 0

for node in NODES:
    path     = os.path.join(BASE, 'html', node, 'index.html')
    bak_path = path + '.bak'

    # Step 1: restore from backup
    if os.path.exists(bak_path):
        shutil.copy2(bak_path, path)
        print(f'  RESTORED {node} from .bak')
    else:
        print(f'  NO BACKUP for {node} — working from current file')

    # Step 2: read restored content
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Step 3: find cut point — use LAST match so we cut at the final script block
    cut_idx = -1
    matched = None
    for pattern in CUT_PATTERNS:
        idx = content.rfind(pattern)
        if idx != -1:
            # Take the earliest among last-matches (start of the final script region)
            if cut_idx == -1 or idx < cut_idx:
                cut_idx = idx
                matched = pattern

    if cut_idx == -1:
        print(f'  ERROR: no cut point found in {node} — skipping')
        continue

    print(f'  CUT at pos {cut_idx} pattern={repr(matched[:40])}')

    # Step 4: verify we're keeping enough content (at least 5 tab divs)
    kept = content[:cut_idx]
    tab_count = len(re.findall(r'id="tab-', kept))
    print(f'    keeping {len(kept)} chars, {tab_count} tab divs')

    if tab_count < 2:
        print(f'  WARNING: only {tab_count} tab divs in kept content — check manually')

    # Step 5: write fixed file
    with open(path, 'w', encoding='utf-8') as f:
        f.write(kept + CLEAN_SCRIPT)

    fixed += 1

    # Step 6: sync
    for dest_rel in SYNC_MAP.get(node, []):
        dest = os.path.join(BASE, dest_rel)
        if os.path.exists(os.path.dirname(dest)):
            shutil.copy2(path, dest)
            print(f'    SYNC → {dest_rel}')

print(f'\n=== DONE: {fixed}/{len(NODES)} fixed ===')
print('Run: fly deploy')
