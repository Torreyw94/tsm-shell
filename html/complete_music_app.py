#!/usr/bin/env python3
"""
complete_music_app.py
1. Wire Song Bank — save on Copy Full Version, display saved songs
2. Wire Artist DNA tab — show live DNA scores and learned songs
3. Wire Revision Mode tab — functional shortcut to re-run chain
"""

path = 'html/music-command/index.html'
txt = open(path).read()

# ── 1. Replace Song Bank placeholder panel ────────────────────────────────────
old_bank = '''        <div class="card tsm-tab-panel" id="panel-bank" style="display:none">
          <div class="section-label">Song Bank</div>
          <div class="card-title">Saved Directions</div>
          <div class="box">Recommended versions and future saved songs will live here. For now, use "Copy Recommended" after a run.</div>
        </div>'''

new_bank = '''        <div class="card tsm-tab-panel" id="panel-bank" style="display:none">
          <div class="section-label">Song Bank</div>
          <div class="card-title">Saved Songs</div>
          <div class="card-sub" style="margin-bottom:14px">Songs are saved automatically when you Copy Full Version or Lock a Hook.</div>
          <div id="songBankList"><div style="color:var(--muted);font-size:12px">No songs saved yet. Complete a run and copy your version.</div></div>
        </div>'''

txt = txt.replace(old_bank, new_bank)
print('Song Bank panel:', 'done' if old_bank not in txt else 'NOT FOUND')

# ── 2. Replace Artist DNA tab placeholder ─────────────────────────────────────
old_dna = '''        <div class="card tsm-tab-panel" id="panel-dna" style="display:none">
          <div class="section-label">Artist DNA</div>
          <div class="card-title">Style Memory</div>
          <div class="box">The system tracks cadence, emotion, structure, imagery, learned songs, and style match as the song evolves.</div>
        </div>'''

new_dna = '''        <div class="card tsm-tab-panel" id="panel-dna" style="display:none">
          <div class="section-label">Artist DNA</div>
          <div class="card-title">Style Memory</div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:14px">
            <div class="box"><div style="font-size:10px;color:var(--muted);text-transform:uppercase;margin-bottom:6px">Cadence</div><div style="font-size:22px;font-weight:700;font-family:var(--mono);color:var(--green)" id="dna-tab-cad">—</div></div>
            <div class="box"><div style="font-size:10px;color:var(--muted);text-transform:uppercase;margin-bottom:6px">Emotion</div><div style="font-size:22px;font-weight:700;font-family:var(--mono);color:var(--green)" id="dna-tab-emo">—</div></div>
            <div class="box"><div style="font-size:10px;color:var(--muted);text-transform:uppercase;margin-bottom:6px">Structure</div><div style="font-size:22px;font-weight:700;font-family:var(--mono);color:var(--green)" id="dna-tab-str">—</div></div>
            <div class="box"><div style="font-size:10px;color:var(--muted);text-transform:uppercase;margin-bottom:6px">Imagery</div><div style="font-size:22px;font-weight:700;font-family:var(--mono);color:var(--green)" id="dna-tab-img">—</div></div>
          </div>
          <div class="section-label">Learned Songs</div>
          <div id="dna-learned-list"><div style="color:var(--muted);font-size:12px">No songs learned yet. Run the chain to build your DNA.</div></div>
        </div>'''

txt = txt.replace(old_dna, new_dna)
print('Artist DNA panel:', 'done' if old_dna not in txt else 'NOT FOUND')

# ── 3. Replace Revision Mode panel ───────────────────────────────────────────
old_rev = '''        <div class="card tsm-tab-panel" id="panel-revision" style="display:none">
          <div class="section-label">Revision Mode</div>
          <div class="card-title">Generate 3 Better Versions</div>
          <div class="card-sub">Use this after your first run. Pick the strongest direction, then improve it again.</div>
          <div style="margin-top:14px;display:flex;gap:10px;flex-wrap:wrap">
            <button class="btn btn-primary" onclick="runAnalysis()">Run Revision Chain</button>
            <button class="btn btn-ghost" onclick="improveRecommended && improveRecommended()">Improve Picked Version</button>
          </div>
        </div>'''

new_rev = '''        <div class="card tsm-tab-panel" id="panel-revision" style="display:none">
          <div class="section-label">Revision Mode</div>
          <div class="card-title">Generate 3 Better Versions</div>
          <div class="card-sub" style="margin-bottom:14px">Paste a new draft or improve your last picked version. The chain runs ZAY → RIYA → DJ and gives you 3 scored options.</div>
          <textarea class="lyric-input" id="revisionInput" placeholder="Paste a lyric to revise, or load your last version..." style="margin-bottom:12px"></textarea>
          <div style="display:flex;gap:10px;flex-wrap:wrap">
            <button class="btn btn-primary" onclick="runRevision()">⚡ Run Revision Chain</button>
            <button class="btn btn-ghost" onclick="loadLastIntoRevision()">Load Last Version</button>
          </div>
          <div id="revisionOutput" style="display:none;margin-top:16px"></div>
        </div>'''

txt = txt.replace(old_rev, new_rev)
print('Revision Mode panel:', 'done' if old_rev not in txt else 'NOT FOUND')

# ── 4. Inject JS for Song Bank + DNA tab + Revision Mode ─────────────────────
new_js = '''
<script id="tsm-app-complete">
(function(){
  if(window.__TSM_APP_COMPLETE__) return;
  window.__TSM_APP_COMPLETE__ = true;

  // ── Song Bank ──────────────────────────────────────────────────────────────
  window.__songBank = window.__songBank || [];

  function saveSong(data){
    const song = {
      id: Date.now(),
      title: 'Song ' + (window.__songBank.length + 1),
      hook: window.__lockedHook || '',
      full: window.__refinedVersion || window.__pickedVersion || '',
      score: data && data.score ? data.score : null,
      savedAt: new Date().toLocaleTimeString()
    };
    window.__songBank.unshift(song);
    window.__songBank = window.__songBank.slice(0, 20);
    renderSongBank();
    return song;
  }

  function renderSongBank(){
    const el = document.getElementById('songBankList');
    if(!el) return;
    if(!window.__songBank.length){
      el.innerHTML = '<div style="color:var(--muted);font-size:12px">No songs saved yet.</div>';
      return;
    }
    el.innerHTML = window.__songBank.map((s,i) => `
      <div style="background:var(--bg4);border:1px solid var(--border);border-radius:8px;padding:14px;margin-bottom:10px">
        <div style="display:flex;justify-content:space-between;margin-bottom:6px">
          <div style="font-weight:700;font-size:13px">${s.title}</div>
          <div style="font-size:10px;color:var(--muted);font-family:var(--mono)">${s.savedAt}</div>
        </div>
        ${s.hook ? '<div style="font-size:11px;color:var(--green);font-family:var(--mono);margin-bottom:6px">Hook: ' + s.hook.split('\\n')[0] + '</div>' : ''}
        <div style="font-size:11px;color:var(--muted);white-space:pre-wrap;line-height:1.5">${(s.full||'').slice(0,120)}${s.full&&s.full.length>120?'...':''}</div>
        <button onclick="loadSongFromBank(${i})" style="margin-top:8px;background:transparent;border:1px solid var(--border2);color:var(--muted);padding:4px 10px;border-radius:4px;font-size:11px;cursor:pointer">Load into editor</button>
      </div>
    `).join('');
  }

  window.loadSongFromBank = function(i){
    const song = window.__songBank[i];
    if(!song) return;
    const input = document.getElementById('lyricInput');
    if(input) input.value = song.full;
    // switch to draft tab
    document.querySelectorAll('.tab').forEach(t=>{
      if(t.textContent.trim()==='Draft + Analysis') t.click();
    });
  };

  // Hook into copyExport to auto-save
  const oldCopyExport = window.copyExport;
  window.copyExport = async function(){
    saveSong({});
    if(typeof oldCopyExport === 'function') return oldCopyExport.apply(this, arguments);
    const txt = window.__refinedVersion || window.__pickedVersion || '';
    try{ await navigator.clipboard.writeText(txt); } catch(e){}
    if(typeof window.showToast === 'function') window.showToast('Full version copied and saved to Song Bank');
  };

  // Hook into copyHook
  const oldCopyHook = window.copyHook;
  window.copyHook = async function(){
    saveSong({});
    if(typeof oldCopyHook === 'function') return oldCopyHook.apply(this, arguments);
    const txt = window.__lockedHook || '';
    try{ await navigator.clipboard.writeText(txt); } catch(e){}
    if(typeof window.showToast === 'function') window.showToast('Hook copied and saved to Song Bank');
  };

  // ── Artist DNA Tab ─────────────────────────────────────────────────────────
  function syncDNATab(){
    const fields = [
      ['dna-tab-cad', 'dna-cad'],
      ['dna-tab-emo', 'dna-emo'],
      ['dna-tab-str', 'dna-str'],
      ['dna-tab-img', 'dna-img']
    ];
    fields.forEach(([tabId, sideId])=>{
      const tab = document.getElementById(tabId);
      const side = document.getElementById(sideId);
      if(tab && side) tab.textContent = side.textContent;
    });

    // learned songs
    const el = document.getElementById('dna-learned-list');
    if(!el) return;
    const count = parseInt((document.getElementById('dna-songs')||{}).textContent||'0');
    if(!count){
      el.innerHTML = '<div style="color:var(--muted);font-size:12px">No songs learned yet.</div>';
      return;
    }
    el.innerHTML = Array.from({length:count}).map((_,i)=>`
      <div style="background:var(--bg4);border:1px solid var(--border);border-radius:6px;padding:10px;margin-bottom:8px;font-size:12px">
        <span style="color:var(--green);font-family:var(--mono)">Run #${i+1}</span>
        <span style="color:var(--muted);margin-left:8px">DNA updated · cadence + emotion weighted</span>
      </div>
    `).join('');
  }

  // Sync DNA tab whenever it's clicked
  document.querySelectorAll('.tab,.nav-item').forEach(el=>{
    el.addEventListener('click', ()=>{
      const txt = el.textContent.replace(/[✦⟳◈◻]/g,'').trim();
      if(txt === 'Artist DNA') setTimeout(syncDNATab, 100);
      if(txt === 'Song Bank') setTimeout(renderSongBank, 100);
    });
  });

  // ── Revision Mode ──────────────────────────────────────────────────────────
  window.loadLastIntoRevision = function(){
    const txt = window.__refinedVersion || window.__pickedVersion || '';
    const input = document.getElementById('revisionInput');
    if(input) input.value = txt;
  };

  window.runRevision = async function(){
    const input = document.getElementById('revisionInput');
    const draft = (input ? input.value : '').trim();
    if(!draft) return;

    const out = document.getElementById('revisionOutput');
    if(out){ out.style.display='block'; out.innerHTML='<div style="color:var(--muted);font-size:12px">Running ZAY → RIYA → DJ chain...</div>'; }

    try{
      const r = await fetch('/api/music/revision/run',{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({draft, request:'revision mode'})
      });
      const data = await r.json();
      const opts = data.session && data.session.options ? data.session.options : [];
      if(out){
        out.innerHTML = opts.map((o,i)=>`
          <div style="background:var(--bg4);border:1px solid ${i===0?'var(--green)':'var(--border)'};border-radius:8px;padding:14px;margin-bottom:10px">
            <div style="font-size:10px;color:var(--muted);text-transform:uppercase;margin-bottom:6px;font-family:var(--mono)">${o.title||'Option '+(i+1)}</div>
            <div style="font-size:12px;font-family:var(--mono);white-space:pre-wrap;line-height:1.6">${o.output||''}</div>
            <div style="margin-top:8px;display:flex;gap:8px">
              <button onclick="loadRevisionOption(${JSON.stringify(o.output||'').replace(/'/g,'&#39;')})" style="background:var(--green);color:#000;border:none;padding:5px 12px;border-radius:4px;font-size:11px;font-weight:700;cursor:pointer">Use This</button>
            </div>
          </div>
        `).join('');
      }
    } catch(e){
      if(out) out.innerHTML = '<div style="color:var(--muted)">Error running chain. Try again.</div>';
    }
  };

  window.loadRevisionOption = function(txt){
    const input = document.getElementById('lyricInput');
    if(input) input.value = txt;
    document.querySelectorAll('.tab').forEach(t=>{
      if(t.textContent.trim()==='Draft + Analysis') t.click();
    });
  };

  // Also sync DNA on render
  const oldRender = window.render;
  if(typeof oldRender === 'function'){
    window.render = function(){
      const result = oldRender.apply(this, arguments);
      setTimeout(syncDNATab, 200);
      return result;
    };
  }

})();
</script>
'''

# Inject before </body>
txt = txt.replace('</body>', new_js + '\n</body>')
print('JS injected')

open(path, 'w').write(txt)
print('All done.')
