#!/usr/bin/env bash
set -euo pipefail

FILES=(
  html/music-command/index.html
  html/music-command/index2.html
  html/music-command/presentation-live.html
  html/music-command/marketing.html
  html/music-command/how-to-guide.html
)

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_token_nav_fix

python3 <<'PY'
from pathlib import Path
import re

files = [
  "html/music-command/index.html",
  "html/music-command/index2.html",
  "html/music-command/presentation-live.html",
  "html/music-command/marketing.html",
  "html/music-command/how-to-guide.html"
]

patch = r'''
<script id="tsm-token-navigation-fix">
(function(){
  const params = new URLSearchParams(location.search);
  const urlToken = params.get('demo_token');

  if(urlToken){
    localStorage.setItem('tsm_music_demo_token', urlToken);
  }

  const token = urlToken || localStorage.getItem('tsm_music_demo_token');

  // Preserve token across internal Music Command links.
  if(token){
    document.querySelectorAll('a[href*="/html/music-command/"]').forEach(a => {
      try{
        const u = new URL(a.getAttribute('href'), location.origin);
        if(!u.searchParams.get('demo_token')){
          u.searchParams.set('demo_token', token);
          a.setAttribute('href', u.pathname + u.search + u.hash);
        }
      }catch(e){}
    });
  }

  // If a stale token causes an expired/invalid screen, user can clear it with ?clear_demo=1
  if(params.get('clear_demo') === '1'){
    localStorage.removeItem('tsm_music_demo_token');
    const clean = location.pathname + '?v=clean';
    location.replace(clean);
  }
})();
</script>
'''

for rel in files:
    p = Path(rel)
    if not p.exists():
        continue

    html = p.read_text(encoding="utf-8", errors="ignore")
    html = re.sub(r'<script id="tsm-token-navigation-fix">.*?</script>', '', html, flags=re.S)

    if "</body>" in html:
      html = html.replace("</body>", patch + "\n</body>")
    else:
      html += "\n" + patch

    p.write_text(html, encoding="utf-8")
    print("patched", rel)
PY

git add "${FILES[@]}"
git commit -m "Fix Music Command token navigation across protected demo pages" || true
fly deploy --local-only
