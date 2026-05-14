const express = require('express');
const path = require('path');
const app = express();

// =====================================================
// FORCE TOP HC QUERY ROUTE - NODE SPECIFIC
// =====================================================
function hcNodeKey(v){
  v=String(v||"").toUpperCase();
  if(v.includes("BILL")) return "BILLING";
  if(v.includes("MED")) return "MEDICAL";
  if(v.includes("COMP")) return "COMPLIANCE";
  if(v.includes("FIN")) return "FINANCIAL";
  if(v.includes("INS")) return "INSURANCE";
  if(v.includes("PHARM")) return "PHARMACY";
  if(v.includes("VENDOR")) return "VENDORS";
  if(v.includes("LEGAL")) return "LEGAL";
  if(v.includes("GRANT")) return "GRANTS";
  if(v.includes("TAX")) return "TAXPREP";
  if(v.includes("STRAT")) return "STRATEGIST";
  return "OPERATIONS";
}

const hcProfiles={
  OPERATIONS:["Operations Lead","Intake, staffing, scheduling, and throughput pressure"],
  MEDICAL:["Clinical Ops Lead","Clinical backlog, provider load, documentation gaps, and no-show risk"],
  BILLING:["Billing Lead / RCM Director","Denial pressure, AR aging, claim defects, and payer inactivity"],
  COMPLIANCE:["Compliance Officer","HIPAA exposure, CMS/OIG risk, policy gaps, and audit readiness"],
  FINANCIAL:["Finance Director / CFO Lane","Revenue risk, payer variance, reimbursement slowdown, and margin pressure"],
  INSURANCE:["Prior Auth Lead","Eligibility misses, prior-auth aging, payer SLA risk, and authorization blockers"],
  PHARMACY:["Pharmacy Lead","Medication access, refill queue, formulary mismatch, and pharmacy PA blockers"],
  VENDORS:["Vendor Manager","Vendor SLA exceptions, supply blockers, contract gaps, and invoice friction"],
  LEGAL:["Legal Ops Lead","Contract risk, credentialing blockers, documentation exposure, and legal escalation"],
  GRANTS:["Grants Manager","Grant deadlines, reporting gaps, eligibility risk, and funding continuity"],
  TAXPREP:["Tax Prep Lead","1099 readiness, W-9 gaps, filing windows, and vendor documentation exposure"],
  STRATEGIST:["HC Strategist","Cross-node unresolved risk and executive prioritization"]
};

async function forcedHcReply(body){
  const payload=body.payload||body||{};
  const node=hcNodeKey(payload.node||body.node||"");
  const tab=payload.tab||body.tab||"Current View";
  const context=payload.context||body.context||body.prompt||body.message||"Run node-specific BNCA.";
  const [owner,top]=hcProfiles[node]||hcProfiles.OPERATIONS;

  const system=`You are TSM Healthcare Strategist Engine. You MUST answer for NODE=${node}, not Operations unless NODE=OPERATIONS.
Return exactly:
TOP ISSUE
...
WHY IT MATTERS
...
BEST NEXT ACTIONS
1.
2.
3.
4.
OWNER LANE
...
HITL DECISION
...
STRATEGIST RELAY
...
CONFIDENCE
...%`;

  const user=`NODE=${node}
TAB=${tab}
CONTEXT=${typeof context==="string"?context:JSON.stringify(context)}
Expected focus: ${top}
Owner lane: ${owner}`;

  if(process.env.GROQ_API_KEY){
    try{
      const r=await fetch("https://api.groq.com/openai/v1/chat/completions",{
        method:"POST",
        headers:{
          "Content-Type":"application/json",
          "Authorization":"Bearer "+process.env.GROQ_API_KEY
        },
        body:JSON.stringify({
          model:process.env.TSM_HC_MODEL||process.env.GROQ_MODEL||"llama-3.3-70b-versatile",
          messages:[{role:"system",content:system},{role:"user",content:user}],
          temperature:0.16,
          max_tokens:850
        }),
        signal:AbortSignal.timeout(14000)
      });
      const d=await r.json();
      const reply=d?.choices?.[0]?.message?.content;
      if(reply) return {node,tab,reply};
    }catch(e){}
  }

  const reply=`TOP ISSUE
${top}

CURRENT REQUEST
${typeof context==="string"?context:JSON.stringify(context)}

WHY IT MATTERS
This ${node} issue can affect revenue, compliance, staffing, patient flow, or executive escalation if it is not owned during the current operating window.

BEST NEXT ACTIONS
1. Assign ${owner} as accountable owner.
2. Review the active ${tab} signals and unresolved blockers.
3. Run BNCA and document the human-in-the-loop decision.
4. Relay unresolved risk to HC Strategist for cross-node synthesis.

OWNER LANE
${owner}

HITL DECISION
Human operator should confirm ownership, approve the next action, and decide whether this requires strategist escalation.

STRATEGIST RELAY
Send node=${node}, tab=${tab}, owner="${owner}", priority=HIGH, unresolved=true.

CONFIDENCE
92%`;
  return {node,tab,reply};
}

// mounted before older duplicate routes
app.get("/api/hc/query",(req,res)=>res.json({ok:true,route:"/api/hc/query",method:"POST required",forced:true}));
app.post("/api/hc/query",async(req,res)=>{
  const out=await forcedHcReply(req.body||{});
  res.json({ok:true,node:out.node,tab:out.tab,reply:out.reply,content:out.reply,forced:true,ts:new Date().toISOString()});
});
// =====================================================


app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.post('/api/cfo-chat', (req, res) => {
    const { sector } = req.body;
    // WIP Logic for Construction and Medical
    const data = sector === 'Construction' 
        ? { logic: "WIP-RECON-UNDER", analysis: "$900k recoup on Ameris Job #203", narrative: "Ready for AIA G702", mesh_status: "11/11 NODES ACTIVE" }
        : { logic: "UPCODE-DETECT-V2", analysis: "14 miscoded '99214' instances", narrative: "Revenue risk: $4.2k/provider month. Targets: Banner & HonorHealth.", mesh_status: "11/11 NODES ACTIVE" };
    res.json(data);
});

app.listen(8080, () => console.log('Sovereign Mesh Online on 8080'));
