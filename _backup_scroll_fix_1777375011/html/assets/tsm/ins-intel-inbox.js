(function(){
  const STORAGE_KEY = 'tsm_insurance_intel_inbox';

  function readInbox(){
    try{return JSON.parse(localStorage.getItem(STORAGE_KEY)||'[]')}catch{return[]}
  }
  function writeInbox(list){
    localStorage.setItem(STORAGE_KEY, JSON.stringify(list.slice(0,75)));
  }
  function escapeHtml(x){
    return String(x||'').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  function saveIntel(payload){
    const item = {
      id:'ins-'+Date.now(),
      source:payload.source||'TSM Insurance Intelligence',
      audience:payload.audience||payload.label||'Insurance',
      title:payload.title||'Insurance BNCA / Node Finding',
      bnca:payload.bnca||payload.summary||payload.output||'',
      compliance:payload.compliance||'',
      coverage:payload.coverage||'',
      claims:payload.claims||'',
      risk:payload.risk||'',
      metrics:payload.metrics||{},
      ts:new Date().toISOString()
    };
    const list=readInbox();
    list.unshift(item);
    writeInbox(list);
    renderInbox();
    toast('Saved intelligence to inbox');
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
      metrics:{revenue:'$5,000+',status:'ready'}
    });
  }

  function renderInbox(){
    const listEl=document.getElementById('insIntelInboxList');
    const countEl=document.getElementById('insIntelCount');
    if(countEl) countEl.textContent=readInbox().length;
    if(!listEl) return;
    const list=readInbox();
    listEl.innerHTML=list.length ? list.map(item=>`
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
    `).join('') : `<div class="ins-intel-empty">No saved intelligence yet. Run the Insurance Presentation cycle, then open this drawer.</div>`;
  }

  function toggleInbox(open){
    const panel=document.getElementById('insIntelInbox');
    if(!panel) return;
    const shouldOpen = typeof open === 'boolean' ? open : !panel.classList.contains('open');
    panel.classList.toggle('open', shouldOpen);
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

  function installInbox(){
    if(document.getElementById('insIntelInbox')) return;

    const css=document.createElement('style');
    css.id='ins-intel-inbox-css';
    css.textContent=`
      #insIntelFab{
        position:fixed;left:18px;top:96px;z-index:999999;
        background:#141108;color:#F5DFA0;border:1px solid #C9A84C;border-radius:999px;
        padding:9px 13px;font:900 11px monospace;letter-spacing:.08em;cursor:pointer;
        box-shadow:0 12px 35px rgba(0,0,0,.45)
      }
      #insIntelInbox{
        position:fixed;left:18px;top:138px;bottom:18px;width:min(520px,calc(100vw - 36px));
        z-index:999999;background:#101318;color:#e8ede6;border:1px solid #C9A84C;
        border-radius:14px;font-family:monospace;box-shadow:0 24px 80px rgba(0,0,0,.65);
        transform:translateX(calc(-100% - 30px));transition:transform .22s ease;overflow:hidden;
        display:flex;flex-direction:column;
      }
      #insIntelInbox.open{transform:translateX(0)}
      #insIntelInbox .ins-head{display:flex;justify-content:space-between;gap:10px;align-items:flex-start;padding:14px;border-bottom:1px solid #1f2535}
      #insIntelInbox .ins-title{color:#E8C870;font-weight:900;letter-spacing:.12em}
      #insIntelInbox .ins-actions{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}
      #insIntelInbox button{background:transparent;color:#E8C870;border:1px solid #C9A84C;border-radius:8px;padding:7px 9px;font:900 10px monospace;cursor:pointer}
      #insIntelInboxList{padding:12px;overflow:auto}
      .ins-intel-card{background:#0a0b0d;border:1px solid #1f2535;border-radius:12px;padding:12px;margin:0 0 10px}
      .ins-intel-top{display:flex;justify-content:space-between;gap:12px;color:#fff}
      .ins-intel-top span{color:#7a8f88;font-size:10px}
      .ins-intel-meta{color:#7a8f88;font-size:10px;margin:5px 0 9px}
      .ins-intel-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:7px;margin-bottom:9px}
      .ins-intel-grid div{background:#151920;border:1px solid #1f2535;border-radius:8px;padding:9px}
      .ins-intel-grid b,.ins-intel-bnca b{color:#3BBFAF}
      .ins-intel-grid p{margin-top:5px;color:#d6dfd8;line-height:1.4}
      .ins-intel-bnca{background:#141108;border:1px solid #C9A84C;border-radius:8px;padding:10px;color:#F5DFA0;line-height:1.45}
      .ins-intel-empty{color:#7a8f88;padding:14px;border:1px dashed #1f2535;border-radius:10px}
      #insIntelToast{position:fixed;left:50%;bottom:22px;transform:translateX(-50%);background:#141108;color:#F5DFA0;border:1px solid #C9A84C;border-radius:10px;padding:10px 14px;z-index:1000000;font:900 12px monospace}
    `;
    document.head.appendChild(css);

    const fab=document.createElement('button');
    fab.id='insIntelFab';
    fab.innerHTML='INTEL INBOX · <span id="insIntelCount">0</span>';
    fab.onclick=()=>toggleInbox();
    document.body.appendChild(fab);

    const panel=document.createElement('aside');
    panel.id='insIntelInbox';
    panel.innerHTML=`
      <div class="ins-head">
        <div>
          <div class="ins-title">TSM INSURANCE INTELLIGENCE INBOX</div>
          <div style="color:#7a8f88;font-size:11px">Saved BNCA outputs, compliance findings, coverage gaps, claims/risk analysis.</div>
          <div class="ins-actions">
            <button onclick="window.InsIntelInbox.seedDemoIntel()">SEED DEMO INTEL</button>
            <button onclick="window.InsIntelInbox.renderInbox()">REFRESH</button>
            <button onclick="window.InsIntelInbox.clearInbox()">CLEAR</button>
          </div>
        </div>
        <button onclick="window.InsIntelInbox.toggleInbox(false)">CLOSE</button>
      </div>
      <div id="insIntelInboxList"></div>
    `;
    document.body.appendChild(panel);
    renderInbox();
  }

  window.InsIntelInbox={saveIntel,seedDemoIntel,renderInbox,clearInbox,readInbox,toggleInbox};

  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',installInbox);
  else installInbox();
})();
