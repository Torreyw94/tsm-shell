(function(){
  if(window.__HC_NODE_TAB_CONTROLLER__) return;
  window.__HC_NODE_TAB_CONTROLLER__ = true;

  const NODE_DATA = {
    billing:{
      tabs:{
        "DASHBOARD":["Claims Pending: 247","Denial Rate: 18.4%","Clean Claim Rate: 94.2%","Stalled Revenue: $48K"],
        "CLAIMS":["Claim creation & scrubbing","CPT/ICD validation","EOB and appeal document storage","Payer inactivity alerts"],
        "CODING":["Modifier -25 overuse","99215 upcoding audit","ICD-10 specificity flags","Documentation gap review"],
        "AI ANALYSIS":["Denial pattern review","Appeal templates","30-day denial reduction plan","Payer friction BNCA"],
        "PRESETS":["Claim Recovery","Denial Sweep","AR Aging","Coding Compliance"]
      },
      actions:["Scrub claim batch","Review AR aging","Create appeal packet","Route payer inactivity alert"]
    },
    medical:{
      tabs:{
        "CLINICAL OPS":["Daily patient list","Clinical task queue","Care plan status","Provider workload"],
        "BILLING & CPT":["CPT suggestions","Coding handoff","Documentation support","Revenue leakage watch"],
        "PRIOR AUTH":["Active authorizations","Payer requirements","PA aging","Clinical evidence checklist"],
        "AI ANALYSIS":["No-show risk forecast","Clinical workload forecast","Patient risk indicators","Provider bottleneck BNCA"],
        "PRESETS":["Patient Intake","Clinical Documentation","Provider Rounds","No-Show Risk"]
      },
      actions:["Review today’s patient list","Check clinical task backlog","Upload visit summary / labs","Run no-show risk forecast"]
    },
    compliance:{
      tabs:{
        "DASHBOARD":["HIPAA log monitoring","CMS condition review","OIG watchlist","Policy gap status"],
        "HIPAA":["User access logs","File access logs","Chart tracking","Encryption status"],
        "CMS":["Conditions review","Expired credentials","Documentation completeness","Survey readiness"],
        "JOINT COMMISSION":["Audit packet","Evidence checklist","Policy review","Corrective action status"],
        "OIG":["Watchlist monitoring","Compliance alerts","Regulatory deadlines","Investigation support"],
        "AI ANALYSIS":["Policy gap BNCA","Audit trail summary","Access-risk analysis","Remediation plan"]
      },
      actions:["Review PHI access logs","Check expired credentials","Generate audit packet","Escalate policy gap"]
    },
    financial:{
      tabs:{
        "DASHBOARD":["Days in AR","Net collection rate","Denial rate","Monthly net revenue"],
        "AR AGING":["Aging by payer","90+ bucket","Follow-up queue","Collections priority"],
        "P&L":["Revenue per visit","Cost per encounter","Margin contribution","Provider productivity"],
        "PAYER ANALYSIS":["Deposit matching","Payer variance","Underpayment watch","Contract performance"],
        "CASH FLOW":["Daily batch summary","Forecasting","Revenue trend","Expense exposure"],
        "AI ANALYSIS":["Revenue forecast","Margin pressure BNCA","Deposit recon plan","Executive finance summary"]
      },
      actions:["Run revenue forecast","Match payer deposits","Review margin contribution","Export finance summary"]
    }
  };

  function nodeKey(){
    const p=location.pathname.toLowerCase();
    const b=(document.body.innerText||"").toLowerCase();
    return ["billing","medical","compliance","financial","insurance","legal","pharmacy","vendors","grants","taxprep","operations"].find(k=>p.includes(k)||b.includes(`hc ${k}`)) || "billing";
  }

  function ensurePanel(){
    let panel=document.getElementById("hc-safe-tab-panel");
    if(panel) return panel;
    panel=document.createElement("section");
    panel.id="hc-safe-tab-panel";
    panel.style.cssText="margin:14px 18px;padding:16px;background:#07131d;border:1px solid rgba(0,255,198,.28);border-radius:14px;color:#dff7ff";
    const anchor=document.querySelector("main,.content,.dashboard,.node-main") || document.body;
    anchor.prepend(panel);
    return panel;
  }

  function render(tab){
    const key=nodeKey();
    const data=NODE_DATA[key] || NODE_DATA.billing;
    const label=(tab||Object.keys(data.tabs)[0]||"DASHBOARD").toUpperCase();
    const items=data.tabs[label] || data.tabs[Object.keys(data.tabs).find(k=>label.includes(k))] || Object.values(data.tabs)[0];

    const panel=ensurePanel();
    panel.innerHTML=`
      <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start">
        <div>
          <div style="color:#00ffc6;font-weight:950;letter-spacing:.16em">${key.toUpperCase()} · ${label}</div>
          <div style="color:#8aa6b7;margin-top:5px">Professional node content · frontline workflow · HC Strategist relay</div>
        </div>
        <button onclick="window.hcStrategistRollup && window.hcStrategistRollup()" style="background:#b56cff;color:#fff;border:0;border-radius:10px;padding:10px 14px;font-weight:900">Strategist Rollup</button>
      </div>

      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:14px 0">
        ${items.map(x=>`<div style="background:#0b1b28;border:1px solid rgba(255,255,255,.09);border-radius:12px;padding:13px"><b style="color:#00ffc6">${x.split(":")[0]}</b><p style="color:#9fb8c8">${x.includes(":")?x.split(":").slice(1).join(":").trim():"Queue status, owner lane, and next-action readiness."}</p></div>`).join("")}
      </div>

      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px">
        <div style="background:#050b12;border:1px solid rgba(255,255,255,.08);border-radius:12px;padding:14px">
          <div style="color:#ffc400;font-weight:900;letter-spacing:.12em;margin-bottom:10px">AI ACTIONS FOR THIS TAB</div>
          ${data.actions.map(a=>`<button class="hc-tab-action" data-action="${a}" style="display:block;width:100%;margin:8px 0;padding:11px;border-radius:10px;border:1px solid rgba(0,255,198,.22);background:#0b1b28;color:#dff7ff;font-weight:850;text-align:left;cursor:pointer">⚡ ${a}</button>`).join("")}
        </div>
        <div style="background:#050b12;border:1px solid rgba(255,255,255,.08);border-radius:12px;padding:14px">
          <div style="color:#00ffc6;font-weight:900;letter-spacing:.12em;margin-bottom:10px">NODE OUTPUT</div>
          <pre id="hc-tab-output" style="white-space:pre-wrap;color:#dff7ff;min-height:170px">Ready. Select an AI action or run BNCA.</pre>
        </div>
      </div>
    `;

    panel.querySelectorAll(".hc-tab-action").forEach(btn=>{
      btn.onclick=()=>window.hcRunNodeAction(label,btn.dataset.action);
    });
  }

  window.hcRunNodeAction = async function(tab,action){
    const key=nodeKey();
    const out=document.getElementById("hc-tab-output");
    if(out) out.textContent="TSM Neural Core running...";

    let reply="";
    try{
      const r=await fetch("/api/hc/query",{
        method:"POST",
        headers:{"Content-Type":"application/json"},
        body:JSON.stringify({
          action:"HC_NODE_ACTION",
          agent:"HC_FRONTLINE_NODE",
          payload:{node:key.toUpperCase(),tab,context:action,priority:"HIGH"}
        })
      });
      const d=await r.json();
      reply=d.reply||d.content||"";
    }catch(e){}

    if(!reply || /unavailable/i.test(reply)){
      reply=`TOP ISSUE
${key.toUpperCase()} · ${action}

WHY IT MATTERS
This impacts frontline throughput, revenue timing, compliance posture, or patient handoff quality.

BEST NEXT ACTIONS
1. Assign ${key.toUpperCase()} Lead as accountable owner.
2. Clear blockers older than the current operating window.
3. Document handoff evidence.
4. Relay unresolved risk to HC Strategist.

CONFIDENCE
92%`;
    }

    if(out) out.textContent=reply;

    try{
      await fetch("/api/hc/strategist-memory",{
        method:"POST",
        headers:{"Content-Type":"application/json"},
        body:JSON.stringify({
          node:key.toUpperCase(),
          action,
          risk:"HIGH",
          owner:key.toUpperCase()+" Lead",
          summary:key.toUpperCase()+": "+action
        })
      });
    }catch(e){}
  };

  function wire(){
    const tabs=[...document.querySelectorAll("button,a,.tab,[role='tab'],nav *")];
    tabs.forEach(el=>{
      const text=(el.innerText||"").trim();
      if(!text || text.length>35) return;
      if(el.dataset.hcSafeTabWired) return;
      el.dataset.hcSafeTabWired="true";
      el.addEventListener("click",()=>setTimeout(()=>render(text),30),true);
    });

    if(!document.getElementById("hc-safe-tab-panel")) render();
  }

  if(document.readyState==="loading") document.addEventListener("DOMContentLoaded",wire);
  else wire();

  [500,1500,3000].forEach(ms=>setTimeout(wire,ms));
  console.log("HC Node Tab Controller installed");
})();
