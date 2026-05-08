(function(){
  const appPath = location.pathname;
  const appKey =
    appPath.includes('/az-ins/') ? 'az-insurance-command' :
    appPath.includes('/dme/') ? 'dme-benefits-engine' :
    appPath.includes('/agents-ins/') ? 'agents-intelligence' :
    appPath.includes('/pc-command/') ? 'pc-enterprise-command' :
    appPath.includes('/ins-presentation/') ? 'insurance-presentation' :
    'insurance-app';

  const STORAGE_KEY = 'tsm_insurance_intel_inbox';

  function readInbox(){
    try{return JSON.parse(localStorage.getItem(STORAGE_KEY)||'[]')}catch{return[]}
  }

  function writeInbox(list){
    localStorage.setItem(STORAGE_KEY, JSON.stringify(list.slice(0,75)));
  }

  function saveIntel(payload){
    const item = {
      id: 'ins-' + Date.now(),
      appKey,
      source: payload.source || 'TSM Insurance Intelligence',
      audience: payload.audience || payload.label || 'Insurance',
      title: payload.title || 'Insurance BNCA / Node Finding',
      bnca: payload.bnca || payload.summary || payload.output || '',
      compliance: payload.compliance || '',
      coverage: payload.coverage || '',
      claims: payload.claims || '',
      risk: payload.risk || '',
      metrics: payload.metrics || {},
      ts: new Date().toISOString()
    };
    const list = readInbox();
    list.unshift(item);
    writeInbox(list);
    renderInbox();
    toast('Saved intelligence to app inbox');
    return item;
  }

  function seedDemoIntel(){
    return saveIntel({
      source:'Insurance Presentation Demo',
      audience:'Medicare Agent',
      title:'Medicare + DME BNCA',
      compliance:'CMS compliant. Part B active. SEP / IOEP check required before action.',
      coverage:'CPAP + INR monitoring benefits identified. Estimated unclaimed DME value: $5,000+.',
      claims:'Prior auth needed for CPAP supplier. INR monitoring covered under Part B.',
      risk:'Low denial risk if supplier authorization and documentation are completed.',
      bnca:'APPROVE / EXECUTE — Initiate DME referral, verify Part B, confirm supplier auth, and schedule client benefits review.',
      metrics:{revenue:'$5,000+', status:'ready'}
    });
  }

  function renderInbox(){
    const panel = document.getElementById('insIntelInboxList');
    if(!panel) return;

    const list = readInbox();
    panel.innerHTML = list.length ? list.map(item => `
      <div class="ins-intel-card">
        <div class="ins-intel-top">
          <b>${escapeHtml(item.title)}</b>
          <span>${new Date(item.ts).toLocaleString()}</span>
        </div>
        <div class="ins-intel-meta">${escapeHtml(item.source)} · ${escapeHtml(item.audience)}</div>
        <div class="ins-intel-grid">
          <div><b>Compliance</b><p>${escapeHtml(item.compliance || '—')}</p></div>
          <div><b>Coverage</b><p>${escapeHtml(item.coverage || '—')}</p></div>
          <div><b>Claims</b><p>${escapeHtml(item.claims || '—')}</p></div>
          <div><b>Risk</b><p>${escapeHtml(item.risk || '—')}</p></div>
        </div>
        <div class="ins-intel-bnca"><b>BNCA</b><br>${escapeHtml(item.bnca || 'No BNCA captured.')}</div>
      </div>
    `).join('') : `
      <div class="ins-intel-empty">
        No saved intelligence yet. Run the Insurance Presentation cycle, then open this app.
      </div>
    `;
  }

  function installInbox(){
    if(document.getElementById('insIntelInbox')) return;

    const css = document.createElement('style');
    css.id = 'ins-intel-inbox-css';
    css.textContent = `
      #insIntelInbox{margin:18px;padding:18px;border:1px solid #C9A84C;border-radius:14px;background:#101318;color:#e8ede6;font-family:monospace;box-shadow:0 18px 55px rgba(0,0,0,.35)}
      #insIntelInbox .ins-head{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:12px}
      #insIntelInbox .ins-title{color:#E8C870;font-weight:900;letter-spacing:.12em}
      #insIntelInbox .ins-actions{display:flex;gap:8px;flex-wrap:wrap}
      #insIntelInbox button{background:transparent;color:#E8C870;border:1px solid #C9A84C;border-radius:8px;padding:8px 10px;font:900 11px monospace;cursor:pointer}
      .ins-intel-card{background:#0a0b0d;border:1px solid #1f2535;border-radius:12px;padding:14px;margin:10px 0}
      .ins-intel-top{display:flex;justify-content:space-between;gap:12px;color:#fff}
      .ins-intel-top span{color:#7a8f88;font-size:11px}
      .ins-intel-meta{color:#7a8f88;font-size:11px;margin:5px 0 10px}
      .ins-intel-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:8px;margin-bottom:10px}
      .ins-intel-grid div{background:#151920;border:1px solid #1f2535;border-radius:8px;padding:10px}
      .ins-intel-grid b,.ins-intel-bnca b{color:#3BBFAF}
      .ins-intel-grid p{margin-top:5px;color:#d6dfd8;line-height:1.45}
      .ins-intel-bnca{background:#141108;border:1px solid #C9A84C;border-radius:8px;padding:12px;color:#F5DFA0;line-height:1.5}
      .ins-intel-empty{color:#7a8f88;padding:14px;border:1px dashed #1f2535;border-radius:10px}
      #insIntelToast{position:fixed;left:50%;bottom:22px;transform:translateX(-50%);background:#141108;color:#F5DFA0;border:1px solid #C9A84C;border-radius:10px;padding:10px 14px;z-index:999999;font:900 12px monospace}
    `;
    document.head.appendChild(css);

    const panel = document.createElement('section');
    panel.id = 'insIntelInbox';
    panel.innerHTML = `
      <div class="ins-head">
        <div>
          <div class="ins-title">TSM INSURANCE INTELLIGENCE INBOX</div>
          <div style="color:#7a8f88;font-size:12px">Saved BNCA outputs, compliance findings, coverage gaps, claims/risk analysis.</div>
        </div>
        <div class="ins-actions">
          <button onclick="window.InsIntelInbox.seedDemoIntel()">SEED DEMO INTEL</button>
          <button onclick="window.InsIntelInbox.renderInbox()">REFRESH</button>
          <button onclick="window.InsIntelInbox.clearInbox()">CLEAR</button>
        </div>
      </div>
      <div id="insIntelInboxList"></div>
    `;

    const target = document.querySelector('main') || document.querySelector('.deck') || document.body;
    if(target === document.body) document.body.prepend(panel);
    else target.prepend(panel);

    renderInbox();
  }

  function clearInbox(){
    if(confirm('Clear saved insurance intelligence inbox?')){
      localStorage.removeItem(STORAGE_KEY);
      renderInbox();
    }
  }

  function toast(msg){
    let t=document.getElementById('insIntelToast');
    if(!t){
      t=document.createElement('div');
      t.id='insIntelToast';
      document.body.appendChild(t);
    }
    t.textContent=msg;
    t.style.display='block';
    setTimeout(()=>t.style.display='none',2000);
  }

  function escapeHtml(x){
    return String(x||'').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  window.InsIntelInbox = { saveIntel, seedDemoIntel, renderInbox, clearInbox, readInbox };

  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', installInbox);
  else installInbox();
})();
