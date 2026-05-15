'use strict';
function fmt(n){return new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(n);}
function ts(){return new Date().toISOString();}

async function constructionWIPRecon(b={}){
  const{job='Ameris',costs=5100000,billed=4200000,threshold=50000}=b;
  const gap=costs-billed,pct=Math.round(billed/costs*100),hasGap=gap>threshold;
  return{suite:'construction',logic:'WIP-RECON',job,ts:ts(),
    metrics:{costs_incurred:costs,billed_to_date:billed,gap,billing_pct:pct},
    status:hasGap?'GAP_DETECTED':'BALANCED',action:hasGap?'INVOICE_TRIGGER':'NO_ACTION',
    message:hasGap?`Recoup ${fmt(gap)} — invoice packet queued for ${job} PM approval.`:`${job} WIP balanced.`,
    next_steps:hasGap?['Generate draft invoice','Route to PM for approval','Post to AR ledger','Reconcile WIP balance']:[]};
}

async function healthcareWIPRecon(b={}){
  const{unbilled_services=148,unbilled_value=2300000,denial_risk_pct=23,facility='Main Campus',period='Current Month'}=b;
  const net=Math.round(unbilled_value*(1-denial_risk_pct/100));
  return{suite:'healthcare',logic:'BNCA',facility,period,ts:ts(),
    metrics:{unbilled_services,unbilled_value,denial_risk_pct,net_recovery_estimate:net},
    status:unbilled_services>0?'CLAIMS_PENDING':'CLEAN',action:unbilled_services>0?'CLAIM_BATCH_SUBMIT':'NO_ACTION',
    message:unbilled_services>0?`${unbilled_services} claims queued. Net recovery: ${fmt(net)}.`:'No unbilled services.',
    risk_flag:denial_risk_pct>=20?`Denial risk ${denial_risk_pct}% — review coding.`:null,
    next_steps:unbilled_services>0?['Code review flagged claims','Submit to clearinghouse','Monitor 835 remittance','Post payments']:[]};
}

async function insuranceAuditRecon(b={}){
  const{earned_premium=7800000,audited=6100000,line_of_business='Property & Casualty',period='Current Quarter'}=b;
  const unaudited=earned_premium-audited,pct=Math.round(audited/earned_premium*100),reserve_risk=unaudited>1000000;
  return{suite:'tsm-insurance',logic:'AUDIT-RECON',line_of_business,period,ts:ts(),
    metrics:{earned_premium,audited_premium:audited,unaudited_premium:unaudited,audit_completion_pct:pct},
    status:unaudited>0?'AUDIT_GAP':'FULLY_AUDITED',action:unaudited>0?'AUDIT_SCHEDULE_PUSH':'NO_ACTION',
    message:unaudited>0?`Audit schedule pushed for ${fmt(unaudited)} in unaudited ${line_of_business} premium.`:'All premium audited.',
    reserve_risk_flag:reserve_risk?`Reserve misstatement risk: ${fmt(unaudited)} unaudited.`:null,
    next_steps:unaudited>0?['Push audit schedule','Collect payroll/exposure data','Calculate premium adjustment','Post to policy ledger']:[]};
}

async function finopsAccrualRecon(b={}){
  const{accrued=4400000,invoiced=3900000,cloud_provider='Multi-cloud',period='Current Month',flush_threshold=100000}=b;
  const variance=accrued-invoiced,match=Math.round(invoiced/accrued*100),auto=variance<=flush_threshold;
  return{suite:'finops-suite',logic:'ACCRUAL-RECON',cloud_provider,period,ts:ts(),
    metrics:{accrued_spend:accrued,invoiced_spend:invoiced,variance,invoice_match_rate_pct:match},
    status:variance>0?'VARIANCE_DETECTED':'MATCHED',action:variance>0?(auto?'ACCRUAL_AUTO_FLUSH':'ACCRUAL_FLUSH'):'NO_ACTION',
    message:variance>0?`${fmt(variance)} variance. ${auto?'Auto-flushing':'Manual flush queued'} before period close.`:'Cloud spend reconciled.',
    next_steps:variance>0?['Pull cloud billing invoices','Match to accrual entries',auto?`Auto-flush ${fmt(variance)}`:`Manual review — ${fmt(variance)}`,'Post to GL']:[]};
}

module.exports={constructionWIPRecon,healthcareWIPRecon,insuranceAuditRecon,finopsAccrualRecon};
