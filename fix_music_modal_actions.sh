#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_modal_actions
cp -f "$FILE" "backups/music_modal_actions/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

patch = r'''
<script id="tsm-modal-action-fix">
(function(){
  if(window.__TSM_MODAL_ACTION_FIX__) return;
  window.__TSM_MODAL_ACTION_FIX__ = true;

  window.closeModal = window.closeModal || function(){
    const modal = document.getElementById('onboardingModal');
    if(modal) modal.classList.add('hidden');
  };

  window.startWithSample = window.startWithSample || function(){
    if(typeof window.closeModal === 'function') window.closeModal();

    if(typeof window.loadSample === 'function'){
      window.loadSample();
    } else {
      const input = document.getElementById('lyricInput');
      if(input){
        input.value = `I keep running but the finish line moves
every win feels like just another bruise
they clap when I'm up but go quiet when I bleed
I'm building an empire nobody chose to see`;
      }
    }

    setTimeout(()=>{
      if(typeof window.runAnalysis === 'function') window.runAnalysis();
    }, 350);
  };

  // Bind buttons defensively in case inline handlers fail.
  window.addEventListener('load', function(){
    document.querySelectorAll('button').forEach(btn=>{
      const txt = (btn.textContent || '').trim();
      if(txt.includes('Load Sample')){
        btn.addEventListener('click', function(e){
          if(typeof window.startWithSample === 'function'){
            e.preventDefault();
            window.startWithSample();
          }
        });
      }
      if(txt === 'Start Blank'){
        btn.addEventListener('click', function(e){
          if(typeof window.closeModal === 'function'){
            e.preventDefault();
            window.closeModal();
          }
        });
      }
    });
  });
})();
</script>
'''

html = re.sub(r'<script id="tsm-modal-action-fix">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", patch + "\n</body>")

p.write_text(html, encoding="utf-8")
print("modal actions restored")
PY

git add "$FILE"
git commit -m "Restore Music onboarding modal actions" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=modalfix"
