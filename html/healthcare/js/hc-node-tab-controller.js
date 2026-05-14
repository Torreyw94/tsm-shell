(function(){
  if(window.__HC_FORCE_TAB_POPULATE__) return;
  window.__HC_FORCE_TAB_POPULATE__=true;
  function populate(name){
    let box=document.getElementById("hc-force-tab-content");
    if(!box){box=document.createElement("section");box.id="hc-force-tab-content";box.style.cssText="margin:14px 18px;padding:16px;background:#07131d;border:1px solid rgba(0,255,198,.22);border-radius:16px;color:#dff7ff";(document.querySelector("main,.content,.dashboard,.node-main")||document.body).appendChild(box);}
    const n=window.tsmDetectHCNode?window.tsmDetectHCNode():"OPERATIONS";
    box.innerHTML=`<b style="color:#00ffc6">${n} · ${name||"DASHBOARD"}</b><div style="margin-top:10px;display:grid;grid-template-columns:repeat(4,1fr);gap:10px">
      ${["Queue status","Owner lane","SLA risk","Strategist relay"].map(x=>`<div style="background:#0a1b28;border-radius:10px;padding:12px">${x}<br><small>tab-specific readiness</small></div>`).join("")}
    </div>`;
  }
  function wire(){document.querySelectorAll("button,a,.tab,[role='tab']").forEach(el=>{const txt=(el.innerText||"").trim();if(!txt||el.dataset.forceTab)return;el.dataset.forceTab=1;el.addEventListener("click",()=>setTimeout(()=>populate(txt),120),true);});populate("DASHBOARD");}
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",wire);else wire();
})();
