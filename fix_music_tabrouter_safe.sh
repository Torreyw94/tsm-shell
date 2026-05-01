#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/tabrouter_safe
cp -f "$FILE" "backups/tabrouter_safe/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

safe_script = r'''
<script id="tsm-music-tab-router">
(function(){
  if(window.__TSM_MUSIC_TAB_ROUTER__) return;
  window.__TSM_MUSIC_TAB_ROUTER__ = true;

  function cleanLabel(el){
    return (el.textContent || "").replace(/[^\w\s+&]/g,"").trim();
  }

  function ensurePanels(){
    var workspace = document.querySelector(".workspace");
    if(!workspace || document.getElementById("panel-revision")) return;

    workspace.insertAdjacentHTML("beforeend", [
      '<div class="card tsm-tab-panel" id="panel-revision" style="display:none">',
      '<div class="section-label">Revision Mode</div>',
      '<div class="card-title">Generate 3 Better Versions</div>',
      '<div class="card-sub">Improve your last picked version. The chain runs ZAY, RIYA, and DJ.</div>',
      '<div style="margin-top:14px;display:flex;gap:10px;flex-wrap:wrap">',
      '<button class="btn btn-primary" onclick="runAnalysis()">Run Revision Chain</button>',
      '<button class="btn btn-ghost" onclick="improveRecommended && improveRecommended()">Improve Picked Version</button>',
      '</div></div>',

      '<div class="card tsm-tab-panel" id="panel-generate" style="display:none">',
      '<div class="section-label">Generate</div>',
      '<div class="card-title">Start From a Concept</div>',
      '<div class="card-sub">Load the sample or paste a rough idea, then run the full improvement chain.</div>',
      '<div style="margin-top:14px"><button class="btn btn-primary" onclick="startWithSample()">Load Sample & Run</button></div>',
      '</div>',

      '<div class="card tsm-tab-panel" id="panel-bank" style="display:none">',
      '<div class="section-label">Song Bank</div>',
      '<div class="card-title">Saved Directions</div>',
      '<div class="box">Recommended versions and future saved songs will live here. Use Export Final Version after a run.</div>',
      '</div>',

      '<div class="card tsm-tab-panel" id="panel-dna" style="display:none">',
      '<div class="section-label">Artist DNA</div>',
      '<div class="card-title">Style Memory</div>',
      '<div class="box">The system tracks cadence, emotion, structure, imagery, learned songs, and style match as the song evolves.</div>',
      '</div>'
    ].join(""));
  }

  function showTab(name){
    ensurePanels();

    document.querySelectorAll(".tab,.nav-item").forEach(function(el){
      el.classList.toggle("active", cleanLabel(el) === name);
    });

    var map = {
      "Draft + Analysis":"draft",
      "Revision Mode":"revision",
      "Generate":"generate",
      "Song Bank":"bank",
      "Artist DNA":"dna"
    };

    var key = map[name] || "draft";
    var normal = document.querySelectorAll(".workspace > .card:not(.tsm-tab-panel), .workspace > .agent-progress, .workspace > .results");
    var panels = document.querySelectorAll(".tsm-tab-panel");

    panels.forEach(function(p){ p.style.display = "none"; });

    if(key === "draft"){
      normal.forEach(function(el){ el.style.display = ""; });
      return;
    }

    normal.forEach(function(el){ el.style.display = "none"; });

    var panel = document.getElementById("panel-" + key);
    if(panel) panel.style.display = "block";
  }

  function bindTabs(){
    ensurePanels();

    document.querySelectorAll(".tab,.nav-item").forEach(function(el){
      if(el.dataset.tsmTabBound) return;
      el.dataset.tsmTabBound = "1";
      el.style.cursor = "pointer";
      el.addEventListener("click", function(){
        var label = cleanLabel(el);
        showTab(label);
      });
    });
  }

  window.addEventListener("load", function(){
    bindTabs();
    showTab("Draft + Analysis");
  });

  setTimeout(bindTabs, 700);
})();
</script>
'''

html = re.sub(r'<script id="tsm-music-tab-router">.*?</script>', safe_script, html, flags=re.S)

p.write_text(html, encoding="utf-8")
print("safe tab router installed")
PY

python3 <<'PY'
from pathlib import Path
import re, subprocess, sys

html = Path("html/music-command/index.html").read_text(errors="ignore")
scripts = re.findall(r"<script[^>]*>(.*?)</script>", html, flags=re.S|re.I)

print("scripts:", len(scripts))

for i, s in enumerate(scripts, 1):
    fn = f"/tmp/music_script_{i}.js"
    Path(fn).write_text(s)
    r = subprocess.run(["node","-c",fn], capture_output=True, text=True)
    if r.returncode:
        print("BROKEN SCRIPT", i)
        print(r.stderr)
        sys.exit(1)

print("All inline scripts passed")
PY

git add "$FILE"
git commit -m "fix: install safe Music tab router" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=safetabs"
