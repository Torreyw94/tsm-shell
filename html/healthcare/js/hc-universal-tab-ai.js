(function(){
  if(window.__HC_FORCE_NODE_AI_PANEL__) return;
  window.__HC_FORCE_NODE_AI_PANEL__=true;
  const actions={
    OPERATIONS:["Rebalance intake queue","Review staff coverage","Clear scheduling backlog","Return ops BNCA"],
    MEDICAL:["Review patient flow","Analyze clinical backlog","Run no-show risk","Return medical BNCA"],
    BILLING:["Scrub claim batch","Review AR aging","Create appeal packet","Return billing BNCA"],
    COMPLIANCE:["Review HIPAA exposure","Check audit readiness","Generate audit packet","Return compliance BNCA"],
    FINANCIAL:["Run revenue forecast","Match payer deposits","Review margin contribution","Return finance BNCA"],
    INSURANCE:["Verify eligibility","Review prior-auth aging","Escalate payer SLA","Return insurance BNCA"],
    PHARMACY:["Review refill queue","Check formulary status","Run medication PA review","Return pharmacy BNCA"],
    VENDORS:["Review vendor SLA","Check supply blocker","Review contract gap","Return vendor BNCA"],
    LEGAL:["Review expiring contract","Check credentialing queue","Open legal escalation","Return legal BNCA"],
    GRANTS:["Track grant deadline","Generate compliance report","Review eligibility","Return grants BNCA"],
    TAXPREP:["Check W-9 gaps","Prepare 1099 packet","Review filing window","Return tax BNCA"]
  };
  function css(){
    if(document.getElementById("hc-force-ai-css"))return;
    const s=document.createElement("style");s.id="hc-force-ai-css";s.textContent=`
    .hc-force-ai{margin:14px 18px;padding:16px;border:1px solid rgba(0,255,198,.28);border-radius:16px;background:#06111b;color:#dff7ff}
    .hc-force-ai h3{margin:0 0 8px;color:#00ffc6;letter-spacing:.12em}
    .hc-force-btn{background:#00ffc6;color:#001;border:0;border-radius:10px;padding:10px 12px;font-weight:950;margin:4px;cursor:pointer}
    .hc-force-out{white-space:pre-wrap;background:#050b12;border:1px solid rgba(0,255,198,.18);border-radius:12px;padding:14px;margin-top:10px;min-height:120px;max-height:360px;overflow:auto}`;
    document.head.appendChild(s);
  }
  function mount(){
    css();
    if(document.getElementById("hc-force-ai"))return;
    const n=window.tsmDetectHCNode?window.tsmDetectHCNode():"OPERATIONS";
    const panel=document.createElement("section");panel.id="hc-force-ai";panel.className="hc-force-ai";
    panel.innerHTML=`<h3>${n} · NODE-SPECIFIC AI / BNCA</h3>
    <div>${(actions[n]||actions.OPERATIONS).map(a=>`<button class="hc-force-btn" data-prompt="${a}">⚡ ${a}</button>`).join("")}</div>
    <pre class="hc-force-out" id="hc-force-out">Ready. Each button sends node + tab context to /api/hc/query.</pre>`;
    (document.querySelector("main,.content,.dashboard,.node-main")||document.body).prepend(panel);
    panel.querySelectorAll("[data-prompt]").forEach(b=>b.onclick=async()=>{
      const out=document.getElementById("hc-force-out"); out.textContent="Running node-specific AI...";
      out.textContent=await window.tsmAskHC(b.dataset.prompt,{node:n});
    });
  }
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",mount);else mount();
  setTimeout(mount,1000);setTimeout(mount,2500);
})();
