#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/music_restore_layer
cp -f "$FILE" "backups/music_restore_layer/index.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/index.html")
html = p.read_text(encoding="utf-8", errors="ignore")

# remove old injected unstable layers
for sid in [
  "tsm-live-ai-coaching",
  "tsm-unlock-flow",
  "tsm-demo-narration-layer",
  "tsm-music-tab-router",
  "tsm-modal-action-fix",
  "tsm-restored-experience-layer"
]:
    html = re.sub(rf'<script id="{sid}">.*?</script>', '', html, flags=re.S)

html = html.replace("Copy Full Version", "Export Final Version")
html = html.replace("Run Full Chain", "⚡ Analyze & Improve My Song")
html = html.replace("Hit Score", "Strong foundation. Not release-ready yet.")
html = html.replace("Promising. Pick the best version and rerun once more.", "Not ready yet. One more pass could make this a strong release.")

layer = r'''
<script id="tsm-restored-experience-layer">
(function(){
  if(window.__TSM_RESTORED_EXPERIENCE__) return;
  window.__TSM_RESTORED_EXPERIENCE__ = true;

  function toast(msg){
    let el=document.getElementById("ai-coach-box");
    if(!el){
      el=document.createElement("div");
      el.id="ai-coach-box";
      el.style.cssText="position:fixed;bottom:90px;left:20px;width:260px;background:rgba(11,18,32,.96);border:1px solid rgba(57,217,138,.35);border-radius:14px;padding:13px;font-size:12px;font-family:monospace;color:#d1fae5;z-index:99999;box-shadow:0 0 24px rgba(57,217,138,.16);line-height:1.45;";
      document.body.appendChild(el);
    }
    el.textContent=msg;
  }

  window.showToast = window.showToast || toast;

  window.closeModal = window.closeModal || function(){
    const m=document.getElementById("onboardingModal");
    if(m) m.classList.add("hidden");
  };

  window.startWithSample = window.startWithSample || function(){
    const input=document.getElementById("lyricInput");
    if(input){
      input.value=[
        "I keep running but the finish line moves",
        "every win feels like just another bruise",
        "they clap when I'm up but go quiet when I bleed",
        "I'm building an empire nobody chose to see"
      ].join("\n");
    }
    if(typeof window.closeModal==="function") window.closeModal();
    setTimeout(function(){
      if(typeof window.runAnalysis==="function") window.runAnalysis();
    },300);
  };

  function coachingSequence(){
    toast("ZAY: tightening cadence so the flow lands cleaner...");
    setTimeout(function(){toast("RIYA: easing the emotion into clearer, more natural lines...");},900);
    setTimeout(function(){toast("DJ: checking structure so the hook direction makes sense...");},1800);
    setTimeout(function(){toast("Scoring strongest version... then I’ll show you what to improve next.");},2700);
  }

  document.addEventListener("click",function(e){
    const btn=e.target.closest("button");
    if(!btn) return;
    const txt=(btn.textContent||"").toLowerCase();

    if(txt.includes("analyze") || txt.includes("run") || txt.includes("improve")){
      coachingSequence();
    }

    if(txt.includes("strongest direction") || txt.includes("pick this")){
      toast("Locking in the strongest direction... now we refine.");
    }

    if(txt.includes("unlock full system")){
      const email=prompt("Enter your email to unlock the full system:");
      if(email){
        toast("Access request captured. Continue evolving your song.");
        console.log("ZY unlock lead:", email);
      }
    }
  },true);

  function ensureConversionBlock(){
    if(document.getElementById("tsm-conversion-block")) return;

    const exportArea = Array.from(document.querySelectorAll("button")).find(b =>
      (b.textContent||"").toLowerCase().includes("export final")
    );

    const parent = exportArea ? exportArea.parentElement : document.querySelector(".workspace");
    if(!parent) return;

    parent.insertAdjacentHTML("afterend", `
      <div id="tsm-conversion-block" style="margin-top:16px;padding:14px;border:1px solid rgba(57,217,138,.3);border-radius:10px;background:rgba(57,217,138,.05)">
        <div style="font-size:12px;color:#39d98a;letter-spacing:.08em;margin-bottom:6px">SYSTEM NOTE</div>
        <div style="font-size:14px;font-weight:600;margin-bottom:8px">This version is stronger because:</div>
        <div style="font-size:12px;color:#a1a1aa;line-height:1.6">
          • Hook is more repeatable<br>
          • Structure flows into the chorus<br>
          • Emotional clarity improved
        </div>
        <div style="margin-top:12px;font-size:13px;font-weight:600">Most creators would stop here.</div>
        <button id="unlockBtn" class="btn btn-primary" style="margin-top:10px;width:100%">Unlock Full System →</button>
      </div>
    `);
  }

  function cleanLabel(el){
    return (el.textContent || "").replace(/[^\w\s+&]/g,"").trim();
  }

  function ensurePanels(){
    const workspace=document.querySelector(".workspace");
    if(!workspace || document.getElementById("panel-revision")) return;

    workspace.insertAdjacentHTML("beforeend", [
      '<div class="card tsm-tab-panel" id="panel-revision" style="display:none"><div class="section-label">Revision Mode</div><div class="card-title">Generate 3 Better Versions</div><div class="card-sub">Improve your last picked version. The chain runs ZAY, RIYA, and DJ.</div><div style="margin-top:14px;display:flex;gap:10px;flex-wrap:wrap"><button class="btn btn-primary" onclick="runAnalysis()">Run Revision Chain</button><button class="btn btn-ghost" onclick="improveRecommended && improveRecommended()">Improve Picked Version</button></div></div>',
      '<div class="card tsm-tab-panel" id="panel-generate" style="display:none"><div class="section-label">Generate</div><div class="card-title">Start From a Concept</div><div class="card-sub">Load the sample or paste a rough idea, then run the full improvement chain.</div><div style="margin-top:14px"><button class="btn btn-primary" onclick="startWithSample()">Load Sample & Run</button></div></div>',
      '<div class="card tsm-tab-panel" id="panel-bank" style="display:none"><div class="section-label">Song Bank</div><div class="card-title">Saved Directions</div><div class="box">Recommended versions and future saved songs will live here. Use Export Final Version after a run.</div></div>',
      '<div class="card tsm-tab-panel" id="panel-dna" style="display:none"><div class="section-label">Artist DNA</div><div class="card-title">Style Memory</div><div class="box">The system tracks cadence, emotion, structure, imagery, learned songs, and style match as the song evolves.</div></div>'
    ].join(""));
  }

  function showTab(name){
    ensurePanels();
    const map={"Draft + Analysis":"draft","Revision Mode":"revision","Generate":"generate","Song Bank":"bank","Artist DNA":"dna"};
    const key=map[name]||"draft";

    document.querySelectorAll(".tab,.nav-item").forEach(el=>{
      el.classList.toggle("active",cleanLabel(el)===name);
    });

    const normal=document.querySelectorAll(".workspace > .card:not(.tsm-tab-panel), .workspace > .agent-progress, .workspace > .results");
    const panels=document.querySelectorAll(".tsm-tab-panel");
    panels.forEach(p=>p.style.display="none");

    if(key==="draft"){
      normal.forEach(el=>el.style.display="");
      return;
    }

    normal.forEach(el=>el.style.display="none");
    const panel=document.getElementById("panel-"+key);
    if(panel) panel.style.display="block";
  }

  function bindTabs(){
    ensurePanels();
    document.querySelectorAll(".tab,.nav-item").forEach(el=>{
      if(el.dataset.tsmBound) return;
      el.dataset.tsmBound="1";
      el.style.cursor="pointer";
      el.addEventListener("click",function(){
        showTab(cleanLabel(el));
      });
    });
  }

  const oldRender=window.render;
  if(typeof oldRender==="function"){
    window.render=function(){
      const result=oldRender.apply(this,arguments);
      setTimeout(function(){
        ensureConversionBlock();
        bindTabs();
      },150);
      return result;
    };
  }

  window.addEventListener("load",function(){
    bindTabs();
    setTimeout(ensureConversionBlock,800);
  });

  setTimeout(function(){
    bindTabs();
    ensureConversionBlock();
  },1000);
})();
</script>
'''

html = html.replace("</body>", layer + "\n</body>")
p.write_text(html, encoding="utf-8")
print("restored experience layer injected")
PY

python3 <<'PY'
from pathlib import Path
import re, subprocess, sys

html = Path("html/music-command/index.html").read_text(errors="ignore")
scripts = re.findall(r"<script[^>]*>(.*?)</script>", html, flags=re.S|re.I)

print("scripts:", len(scripts))
for i,s in enumerate(scripts,1):
    fn=f"/tmp/music_script_{i}.js"
    Path(fn).write_text(s)
    r=subprocess.run(["node","-c",fn],capture_output=True,text=True)
    if r.returncode:
        print("BROKEN SCRIPT",i)
        print(r.stderr)
        sys.exit(1)

print("All inline scripts passed")
PY

git add "$FILE"
git commit -m "restore Music guided experience layer safely" || true
fly deploy --local-only

echo "Open:"
echo "https://tsm-shell.fly.dev/html/music-command/index.html?v=restored"
