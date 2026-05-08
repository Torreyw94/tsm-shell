let currentMode = 'sample';
let selectedSampleId = null;
let selectedFile = null;

const SAMPLES = {
  'bank-recon': { label: 'Bank Reconciliation', content: 'Q1 variance of $48K detected in project escrow. Unreconciled materials cost from February.', risk: 'MED', flags: '3', actions: '2', conf: '94%' },
  'ap-aging': { label: 'AP Aging Report', content: '180-day aging summary. Total outstanding: $312,400. Primary friction with MEP subcontractors.', risk: 'HIGH', flags: '12', actions: '5', conf: '89%' },
  'denial-report': { label: 'Denial Report', content: 'Insurance claim friction. 18.4% denial rate on project liability coverage. Prior auth required.', risk: 'HIGH', flags: '8', actions: '4', conf: '92%' },
  'gl-extract': { label: 'GL Extract', content: 'General Ledger Q1. Revenue vs Budget variance of -12% in Cost Center 402 (Excavation).', risk: 'LOW', flags: '1', actions: '1', conf: '97%' },
  'audit-finding': { label: 'Audit Finding', content: 'Compliance gap found in onsite safety protocols (OSHA). 3 open findings requiring remediation.', risk: 'CRIT', flags: '3', actions: '3', conf: '91%' },
  'variance-report': { label: 'Variance Report', content: 'Labor hours vs estimate. Staffing pressure in specialized masonry. 14% lag in project timeline.', risk: 'MED', flags: '5', actions: '2', conf: '95%' }
};

window.setMode = function(m) {
  currentMode = m;
  document.getElementById('mode-sample').classList.toggle('active', m === 'sample');
  document.getElementById('mode-actual').classList.toggle('active', m === 'actual');
  document.getElementById('panel-sample').style.display = m === 'sample' ? 'block' : 'none';
  document.getElementById('panel-actual').style.display = m === 'actual' ? 'block' : 'none';
};

window.selectSample = function(el, id) {
  document.querySelectorAll('.sample-card').forEach(c => c.classList.remove('selected'));
  el.classList.add('selected');
  selectedSampleId = id;
  document.getElementById('procBtn').disabled = false;
};

window.setPipe = function(step) {
  for(let i=0; i<=4; i++) {
    const dot = document.getElementById('pipe-'+i);
    dot.classList.remove('active', 'done');
    if(i < step) dot.classList.add('done');
    if(i === step) dot.classList.add('active');
  }
};

window.showKPIs = function(data) {
  document.getElementById('kpiRow').style.display = 'grid';
  document.querySelectorAll('.kpi-card').forEach(c => c.classList.add('visible'));
  document.getElementById('kv-risk').textContent = data.risk;
  document.getElementById('kv-flag').textContent = data.flags;
  document.getElementById('kv-action').textContent = data.actions;
  document.getElementById('kv-conf').textContent = data.conf;
};

window.processDoc = async function() {
  const ob = document.getElementById('outBody');
  const os = document.getElementById('outStatus');
  const btn = document.getElementById('procBtn');
  btn.disabled = true;
  ob.className = 'out-body thinking';
  
  setPipe(0); os.textContent = "INGESTING";
  await new Promise(r => setTimeout(r, 600));
  
  setPipe(1); os.textContent = "PARSING";
  await new Promise(r => setTimeout(r, 800));
  
  setPipe(2); os.textContent = "ANALYZING";
  
  try {
    const docData = currentMode === 'sample' ? SAMPLES[selectedSampleId] : { label: selectedFile.name, content: "Actual File" };
    const res = await fetch("https://tsm-core.fly.dev/ask", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ app: "construction-showcase", messages: [{ role: "user", content: "Analyze: " + docData.content }] })
    });
    const data = await res.json();
    
    setPipe(4);
    ob.className = 'out-body';
    ob.innerHTML = `<div style="color:#0f0"><b>${docData.label} Analysis:</b><br><br>${data.reply}</div>`;
    os.textContent = "COMPLETE";
    
    lastReport = { label: docData.label, summary: data.reply, ...docData };
    showKPIs(docData);
    document.getElementById('pushBtn').classList.add('visible');
    document.getElementById('saveBtn').classList.add('visible');
  } catch(e) {
    ob.textContent = "> Handshake Error. Check tsm-core status.";
  }
  btn.disabled = false;
};
