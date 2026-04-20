#!/usr/bin/env python3
import os, shutil

BASE = '/workspaces/tsm-shell'

# Files to patch — html/ is source of truth, script also syncs to fly-build and tmp_root
TARGETS = [
    'html/honor-portal/index.html',
    'html/hc-billing/index.html',
    'html/hc-medical/index.html',
    'html/hc-insurance/index.html',
    'html/hc-command/index.html',
    'html/hc-pharmacy/index.html',
    'html/hc-legal/index.html',
    'html/hc-vendors/index.html',
    'html/hc-grants/index.html',
    'html/hc-strategist/index.html',
]

# The clean tab engine to inject at the end of every file
PATCH = '''
<script>
(function () {

  // ── SINGLE TAB ENGINE ──────────────────────────────────────
  // Handles showTab() and switchTab() — both patterns used across nodes
  // Tab div ids: tab-dash, tab-dashboard, tab-hipaa, tab-cms, etc.

  function switchTab(id, btn) {
    // Hide ALL tab divs regardless of naming pattern
    document.querySelectorAll('[id^="tab-"]').forEach(function(el) {
      el.style.setProperty('display', 'none', 'important');
    });

    // Show target — try tab-{id} first, then bare {id}
    var target = document.getElementById('tab-' + id) || document.getElementById(id);
    if (target) target.style.setProperty('display', 'block', 'important');

    // Update .tab bar buttons (honor portal style)
    document.querySelectorAll('.tab').forEach(function(b) { b.classList.remove('act'); });
    var tabBtn = document.getElementById('t-' + id);
    if (tabBtn) tabBtn.classList.add('act');

    // Update .nav-btn buttons (hc-node style)
    document.querySelectorAll('.nav-btn').forEach(function(b) { b.classList.remove('active'); });
    if (btn) btn.classList.add('active');
  }

  // Alias used by honor portal tab-bar and left nav onclick attrs
  function showTab(id) { switchTab(id, null); }

  // Load prompt into AI tab and fire Q()
  function loadAI(prompt) {
    // Try nav-btn with 'ai' in onclick, fallback to tab switch
    var aiBtn = null;
    document.querySelectorAll('.nav-btn').forEach(function(b) {
      if ((b.getAttribute('onclick') || '').indexOf("'ai'") > -1) aiBtn = b;
    });
    switchTab('ai', aiBtn);
    var inp = document.getElementById('ai-inp');
    if (inp) { inp.value = prompt; inp.focus(); }
    setTimeout(function() {
      if (typeof Q === 'function') Q(prompt, 'ai-btn', 'ai-res');
    }, 50);
  }

  function loadPreset(prompt) { loadAI(prompt); }

  // ── GROQ via /api/groq server proxy (no key in browser) ────
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
      var errEl = document.getElementById(resId.replace('-out','-err').replace('-res',''));
      if (errEl) { errEl.textContent = 'TSM NEURAL ERROR: ' + e.message; if (errEl.classList) errEl.classList.add('show'); }
      else { res.textContent = 'TSM NEURAL ERROR: ' + e.message; }
    }
    btn.disabled = false;
  };

  // ── EXPOSE GLOBALS ─────────────────────────────────────────
  window.switchTab  = switchTab;
  window.showTab    = showTab;
  window.loadAI     = loadAI;
  window.loadPreset = loadPreset;

  // ── BOOT ───────────────────────────────────────────────────
  window.addEventListener('load', function() {
    setTimeout(function() {
      // Find first nav-btn and read its target tab id
      var firstBtn = document.querySelector('.nav-btn');
      var firstTab  = document.querySelector('.tab');
      var tabId = 'dashboard'; // default

      if (firstBtn) {
        var m = (firstBtn.getAttribute('onclick') || '').match(/(?:switchTab|showTab)\\('([^']+)'/);
        if (m) tabId = m[1];
        switchTab(tabId, firstBtn);
      } else if (firstTab) {
        var m2 = (firstTab.getAttribute('onclick') || '').match(/showTab\\('([^']+)'/);
        if (m2) tabId = m2[1];
        switchTab(tabId, null);
        firstTab.classList.add('act');
      } else {
        switchTab(tabId, null);
      }

      console.log('\\u2714 TSM Tab Engine booted: ' + tabId);
    }, 60);
  });

})();
</script>
</body>
</html>'''

# Cut markers — in priority order, first match wins
CUT_MARKERS = [
    '<script>\n// Honor Portal tab fix',
    '<script>\nwindow.switchTab = function(id, btn) {\n  // Hide all',
    '<script id="tsm-core-engine">',
    '<script id="tsm-final-engine">',
    '<script id="tsm-adaptive-engine">',
    '\n<script>\nwindow.switchTab',
    '<script>\nwindow.switchTab',
]

def patch_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find cut point
    cut_idx = -1
    matched_marker = None
    for marker in CUT_MARKERS:
        idx = content.find(marker)
        if idx != -1:
            cut_idx = idx
            matched_marker = marker
            break

    if cut_idx == -1:
        print(f'  SKIP  {filepath} — no cut marker found (may already be clean)')
        return False

    # Backup
    shutil.copy2(filepath, filepath + '.bak')

    # Write clean content + patch
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content[:cut_idx] + PATCH)

    print(f'  FIXED {filepath}  (cut at: {repr(matched_marker[:40])})')
    return True

# Also sync html/ → fly-build/ and tmp_root/
SYNC_MAP = {
    'html/hc-billing/index.html':    ['.fly-build/hc-billing/index.html',    'tmp_root/tsm-deploy/tsm-hc-billing/public/index.html'],
    'html/hc-medical/index.html':    ['.fly-build/hc-medical/index.html',    'tmp_root/tsm-deploy/tsm-hc-medical/public/index.html'],
    'html/hc-insurance/index.html':  ['.fly-build/hc-insurance/index.html',  'tmp_root/tsm-deploy/tsm-hc-insurance/public/index.html'],
    'html/hc-command/index.html':    ['.fly-build/hc-command/index.html',    'tmp_root/tsm-deploy/tsm-hc-command/public/index.html'],
    'html/hc-pharmacy/index.html':   ['.fly-build/hc-pharmacy/index.html',   'tmp_root/tsm-deploy/tsm-hc-pharmacy/public/index.html'],
    'html/hc-legal/index.html':      ['.fly-build/hc-legal/index.html',      'tmp_root/tsm-deploy/tsm-hc-legal/public/index.html'],
    'html/hc-vendors/index.html':    ['.fly-build/hc-vendors/index.html',    'tmp_root/tsm-deploy/tsm-hc-vendors/public/index.html'],
    'html/hc-grants/index.html':     ['.fly-build/hc-grants/index.html',     'tmp_root/tsm-deploy/tsm-hc-grants/public/index.html'],
    'html/hc-strategist/index.html': ['.fly-build/hc-strategist/index.html', 'tmp_root/tsm-deploy/tsm-hc-strategist/public/index.html'],
    'html/honor-portal/index.html':  ['.fly-build/tsm-honorhealth-dee/index.html', 'tmp_root/tsm-deploy/tsm-honorhealth/public/index.html'],
}

print('=== TSM ONE-SHOT TAB FIX ===\n')
fixed = 0
for rel_path in TARGETS:
    full_path = os.path.join(BASE, rel_path)
    if not os.path.exists(full_path):
        print(f'  MISSING {full_path}')
        continue
    ok = patch_file(full_path)
    if ok:
        fixed += 1
        # Sync to fly-build and tmp_root
        if rel_path in SYNC_MAP:
            for dest_rel in SYNC_MAP[rel_path]:
                dest = os.path.join(BASE, dest_rel)
                if os.path.exists(os.path.dirname(dest)):
                    shutil.copy2(full_path, dest)
                    print(f'    SYNC  → {dest_rel}')

print(f'\n=== DONE: {fixed}/{len(TARGETS)} files patched ===')
print('Backups saved as index.html.bak in each directory.')
print('\nNext: redeploy with your normal fly deploy command.')
