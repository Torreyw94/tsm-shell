#!/bin/bash
# Run this ON YOUR SERVER in the directory containing index.html
# It removes all broken script blocks and appends the clean one

FILE="index.html"
BACKUP="index.html.bak"

# 1. Backup
cp "$FILE" "$BACKUP"
echo "✔ Backed up to $BACKUP"

# 2. Remove everything from the first broken switchTab script to </body></html>
#    using Python for reliable multiline replacement
python3 - << 'PYEOF'
with open('index.html', 'r') as f:
    content = f.read()

# Find the cut point — first <script> that defines switchTab at the bottom
cut_marker = '\n<script>\nwindow.switchTab = function(id, btn) {'

idx = content.find(cut_marker)
if idx == -1:
    # Try alternate marker
    cut_marker = '<script>\nwindow.switchTab'
    idx = content.find(cut_marker)

if idx == -1:
    print("ERROR: Could not find cut point. Check index.html manually.")
    exit(1)

# Keep everything before the broken scripts
clean = content[:idx]

# Append the fixed engine
patch = '''
<script>
(function () {

  function switchTab(id, btn) {
    ['dashboard','nodes','intake','alerts','reports','staff'].forEach(function(t) {
      var el = document.getElementById('tab-' + t);
      if (el) el.style.setProperty('display', 'none', 'important');
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
    switchTab('ai', null);
    var inp = document.getElementById('ai-inp');
    if (inp) { inp.value = prompt; inp.focus(); }
    setTimeout(function () { if (typeof Q === 'function') Q(prompt, 'ai-btn', 'ai-res'); }, 50);
  }

  function loadPreset(prompt) { loadAI(prompt); }

  window.Q = async function (prompt, btnId, resId) {
    if (!prompt || !prompt.trim()) return;
    var btn = document.getElementById(btnId);
    var res = document.getElementById(resId);
    if (!btn || !res) return;
    btn.disabled = true;
    res.innerHTML = '<span class="sp">⟳</span> TSM Neural processing...';
    res.classList.add('show');
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
      res.textContent = d.reply.trim();
    } catch (e) {
      res.classList.remove('show');
      var err = document.getElementById(resId.replace('-out', '-err'));
      if (err) { err.textContent = 'TSM NEURAL ERROR: ' + e.message; err.classList.add('show'); }
    }
    btn.disabled = false;
  };

  window.switchTab  = switchTab;
  window.showTab    = showTab;
  window.loadAI     = loadAI;
  window.loadPreset = loadPreset;

  window.addEventListener('load', function () {
    setTimeout(function () {
      ['dashboard','nodes','intake','alerts','reports','staff'].forEach(function(t) {
        var el = document.getElementById('tab-' + t);
        if (el) el.style.setProperty('display', 'none', 'important');
      });
      switchTab('dashboard', null);
      var firstTab = document.getElementById('t-dashboard');
      if (firstTab) firstTab.classList.add('act');
      console.log('\\u2714 TSM Tab Engine: dashboard active');
    }, 60);
  });

})();
</script>
</body>
</html>'''

with open('index.html', 'w') as f:
    f.write(clean + patch)

print("✔ Patch applied. index.html updated.")
PYEOF
