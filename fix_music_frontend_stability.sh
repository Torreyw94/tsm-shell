#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_frontend_stability

cp -f html/music-command/index.html "backups/music_frontend_stability/index.$STAMP.bak"
cp -f html/music-command/index2.html "backups/music_frontend_stability/index2.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

root = Path("/workspaces/tsm-shell")
files = [
  root / "html/music-command/index.html",
  root / "html/music-command/index2.html"
]

stable = r"""
<script id="tsm-music-stable-client">
(function(){
  if (window.__TSM_MUSIC_STABLE_CLIENT__) return;
  window.__TSM_MUSIC_STABLE_CLIENT__ = true;

  async function sleep(ms){ return new Promise(r => setTimeout(r, ms)); }

  window.musicSafeFetch = async function(url, opts={}, retries=3){
    try{
      const res = await fetch(url, opts);
      let data;
      try { data = await res.json(); }
      catch { data = { ok:false, error:'Non-JSON response' }; }

      if(!res.ok || data.ok === false){
        throw new Error(data.error || ('HTTP ' + res.status));
      }

      return data;
    }catch(e){
      if(retries > 0){
        await sleep(450);
        return window.musicSafeFetch(url, opts, retries - 1);
      }
      console.warn('Music API fallback:', url, e.message);
      return { ok:false, fallback:true, error:e.message };
    }
  };

  window.loadMusicSuiteState = async function(){
    if(window.__musicStateLoading) return window.__musicLastState || null;
    window.__musicStateLoading = true;

    const data = await window.musicSafeFetch('/api/music/state');

    window.__musicStateLoading = false;

    if(data && data.ok){
      window.__musicLastState = data;

      const state = data.state || {};
      const statusEls = [
        document.getElementById('keyStatus'),
        document.querySelector('[data-music-status]'),
        document.querySelector('.key-status')
      ].filter(Boolean);

      statusEls.forEach(el => {
        el.textContent = 'SUITE ONLINE';
        if(el.className !== undefined) el.className = (el.className + ' ok').trim();
      });

      const aiText = document.querySelector('.pill.purple, .header-pills .pill');
      if(aiText && /AI|CHECKING|ACTIVE/i.test(aiText.textContent || '')){
        aiText.title = 'Music Suite backend connected';
      }

      console.log('Music Suite State Ready', data);
    }

    return data;
  };

  window.musicAgentPass = async function(payload){
    return window.musicSafeFetch('/api/music/agent-pass', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify(payload || {})
    });
  };

  window.musicStrategy = async function(prompt){
    return window.musicSafeFetch('/api/music/strategy', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({ prompt: prompt || 'Build music strategy' })
    });
  };

  window.addEventListener('load', function(){
    if(window.__musicLoadedOnce) return;
    window.__musicLoadedOnce = true;
    setTimeout(window.loadMusicSuiteState, 350);
  });
})();
</script>
"""

for p in files:
    html = p.read_text(encoding="utf-8", errors="ignore")

    html = re.sub(
        r"<script id=\"tsm-music-stable-client\">.*?</script>",
        "",
        html,
        flags=re.S
    )

    html = html.replace("fetch('/api/music/state')", "musicSafeFetch('/api/music/state')")
    html = html.replace('fetch("/api/music/state")', 'musicSafeFetch("/api/music/state")')

    if "</body>" in html:
        html = html.replace("</body>", stable + "\n</body>")
    else:
        html += "\n" + stable

    p.write_text(html, encoding="utf-8")

print("Music frontend stability layer applied")
PY

node -c server.js

git add html/music-command/index.html html/music-command/index2.html
git commit -m "Add stable Music Suite frontend API client" || true
git push origin main
fly deploy --local-only

echo "DONE"
