#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_tabs_fix

cp -f html/music-command/index.html "backups/music_tabs_fix/index.$STAMP.bak"
cp -f html/music-command/demo-conductor.html "backups/music_tabs_fix/demo-conductor.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

# ----------------------------
# 1) Fix app tabs in index.html
# ----------------------------
p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

patch = r'''
<script id="tsm-music-tab-router">
(function(){
  if(window.__TSM_MUSIC_TAB_ROUTER__) return;
  window.__TSM_MUSIC_TAB_ROUTER__ = true;

  const sections = {
    "Draft + Analysis": "draft",
    "Revision Mode": "revision",
    "Generate": "generate",
    "Song Bank": "bank",
    "Artist DNA": "dna"
  };

  function ensurePanels(){
    let workspace = document.querySelector(".workspace");
    if(!workspace) return;

    if(!document.getElementById("panel-revision")){
      workspace.insertAdjacentHTML("beforeend", `
        <div class="card tsm-tab-panel" id="panel-revision" style="display:none">
          <div class="section-label">Revision Mode</div>
          <div class="card-title">Generate 3 Better Versions</div>
          <div class="card-sub">Use this after your first run. Pick the strongest direction, then improve it again.</div>
          <div style="margin-top:14px;display:flex;gap:10px;flex-wrap:wrap">
            <button class="btn btn-primary" onclick="runAnalysis()">Run Revision Chain</button>
            <button class="btn btn-ghost" onclick="improveRecommended && improveRecommended()">Improve Picked Version</button>
          </div>
        </div>

        <div class="card tsm-tab-panel" id="panel-generate" style="display:none">
          <div class="section-label">Generate</div>
          <div class="card-title">Start From a Concept</div>
          <div class="card-sub">Load the sample or paste a rough idea, then run the full ZAY → RIYA → DJ chain.</div>
          <div style="margin-top:14px">
            <button class="btn btn-primary" onclick="startWithSample()">Load Sample & Run</button>
          </div>
        </div>

        <div class="card tsm-tab-panel" id="panel-bank" style="display:none">
          <div class="section-label">Song Bank</div>
          <div class="card-title">Saved Directions</div>
          <div class="box">Recommended versions and future saved songs will live here. For now, use “Copy Recommended” after a run.</div>
        </div>

        <div class="card tsm-tab-panel" id="panel-dna" style="display:none">
          <div class="section-label">Artist DNA</div>
          <div class="card-title">Style Memory</div>
          <div class="box">The system tracks cadence, emotion, structure, imagery, learned songs, and style match as the song evolves.</div>
        </div>
      `);
    }
  }

  function showTab(name){
    ensurePanels();

    document.querySelectorAll(".tab,.nav-item").forEach(el=>{
      const text = el.textContent.trim();
      const clean = text.replace(/[✦⟳◈◻]/g,"").trim();
      el.classList.toggle("active", clean === name);
    });

    const mainCards = Array.from(document.querySelectorAll(".workspace > .card, .workspace > .agent-progress, .workspace > .results"));
    const panels = document.querySelectorAll(".tsm-tab-panel");
    panels.forEach(p=>p.style.display="none");

    const key = sections[name] || "draft";

    if(key === "draft"){
      mainCards.forEach(el=>{
        if(!el.classList.contains("tsm-tab-panel")) el.style.display="";
      });
      return;
    }

    mainCards.forEach(el=>{
      if(!el.classList.contains("tsm-tab-panel")) el.style.display="none";
    });

    const panel = document.getElementById("panel-" + key);
    if(panel) panel.style.display = "block";
  }

  function bindTabs(){
    ensurePanels();

    document.querySelectorAll(".tab,.nav-item").forEach(el=>{
      if(el.dataset.tsmTabBound) return;
      el.dataset.tsmTabBound = "1";
      el.style.cursor = "pointer";
      el.addEventListener("click", ()=>{
        const clean = el.textContent.replace(/[✦⟳◈◻]/g,"").trim();
        if(sections[clean]) showTab(clean);
      });
    });
  }

  window.addEventListener("load", ()=>{
    bindTabs();
    showTab("Draft + Analysis");
  });

  setTimeout(bindTabs, 700);
})();
</script>
'''

html = re.sub(r'<script id="tsm-music-tab-router">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", patch + "\n</body>")
p.write_text(html, encoding="utf-8")

# ----------------------------
# 2) Clear stale lock banner in conductor
# ----------------------------
p = Path("html/music-command/demo-conductor.html")
html = p.read_text(encoding="utf-8", errors="ignore")

clear_patch = r'''
<script id="tsm-conductor-clear-stale-demo-lock">
(function(){
  try{
    const params = new URLSearchParams(location.search);
    if(params.get("clear_demo") === "1" || !params.get("demo_token")){
      localStorage.removeItem("tsm_music_demo_token");
      sessionStorage.removeItem("tsm_demo_ran");
      sessionStorage.removeItem("tsm_cinematic_demo_ran");
    }

    window.addEventListener("load", function(){
      const banners = Array.from(document.querySelectorAll("div"));
      banners.forEach(el=>{
        const txt = (el.textContent || "").trim();
        if(txt.includes("Demo limit reached") || txt.includes("Unlock required")){
          el.style.display = "none";
        }
      });
    });
  }catch(e){}
})();
</script>
'''

html = re.sub(r'<script id="tsm-conductor-clear-stale-demo-lock">.*?</script>', '', html, flags=re.S)
html = html.replace("</body>", clear_patch + "\n</body>")
p.write_text(html, encoding="utf-8")

print("music app tabs + conductor stale lock fixed")
PY

git add html/music-command/index.html html/music-command/demo-conductor.html
git commit -m "Fix Music app feature tabs and conductor stale lock" || true

fly deploy --local-only

echo
echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=tabsfix"
echo
echo "Conductor:"
echo "https://tsm-shell.fly.dev/html/music-command/demo-conductor.html?clear_demo=1&v=tabsfix"
