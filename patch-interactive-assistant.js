#!/usr/bin/env node
/**
 * patch-interactive-assistant.js
 * Replaces renderFullSong with an interactive step-by-step guided flow:
 * Step 1: Pick a rewrite (3 options)
 * Step 2: Pick a hook (top 5)
 * Step 3: Pick a bridge
 * Step 4: Ad-libs added, full song assembled + saved to bank
 */

const fs = require('fs');
const FILE = 'html/music-command/index.html';
let html = fs.readFileSync(FILE, 'utf8');
fs.writeFileSync(FILE + '.bak.' + Date.now(), html);
console.log('✅ Backup created');

const OLD_RENDER = `  function renderFullSong(data) {
    const { agentData, hooksData, structData, adlibData, fullSong } = data;
    const options = agentData?.options || [];
    const hooks = hooksData?.hooks || [];
    const adlibs = adlibData?.ad_libs || [];
    const structure = structData?.structure || 'verse-chorus-verse-chorus-bridge-chorus';
    document.getElementById('coach-body').innerHTML = \`
      <div style="margin-bottom:16px">
        <div style="font-size:11px;color:#7c3aed;letter-spacing:.1em;text-transform:uppercase;margin-bottom:8px">✅ Full Song Built & Saved to Bank</div>
        <div style="background:#0a1a0a;border:1px solid #14f195;border-radius:8px;padding:12px;font-size:12px;color:#14f195;margin-bottom:12px">
          📦 Saved to Song Bank · Structure: \${structure}
        </div>
      </div>
      <div style="margin-bottom:16px">
        <div style="font-size:11px;color:#a78bfa;letter-spacing:.1em;text-transform:uppercase;margin-bottom:8px">🎣 Top Hooks</div>
        \${hooks.slice(0,5).map((h,i) => \`<div style="background:#12121e;border-radius:6px;padding:8px 10px;margin-bottom:6px;font-size:12px;color:#e2e8f0;border-left:2px solid #7c3aed">\${i+1}. \${h}</div>\`).join('')}
      </div>
      <div style="margin-bottom:16px">
        <div style="font-size:11px;color:#a78bfa;letter-spacing:.1em;text-transform:uppercase;margin-bottom:8px">🎤 Agent Rewrites</div>
        \${options.map(o => \`<div style="background:#12121e;border-radius:6px;padding:10px;margin-bottom:8px;border:1px solid #2a2a3a">
          <div style="font-size:10px;color:#6366f1;margin-bottom:6px">\${o.label}</div>
          <div style="font-size:12px;color:#cbd5e1;line-height:1.6;white-space:pre-wrap">\${o.text}</div>
        </div>\`).join('')}
      </div>
      \${adlibs.length ? \`<div style="margin-bottom:16px">
        <div style="font-size:11px;color:#a78bfa;letter-spacing:.1em;text-transform:uppercase;margin-bottom:8px">🎙️ Ad-libs</div>
        <div style="background:#12121e;border-radius:6px;padding:10px;font-size:13px;color:#fbbf24">\${adlibs.join('  ·  ')}</div>
      </div>\` : ''}
      <div style="margin-bottom:16px">
        <div style="font-size:11px;color:#a78bfa;letter-spacing:.1em;text-transform:uppercase;margin-bottom:8px">📋 Full Song</div>
        <pre style="background:#0d0d14;border-radius:8px;padding:12px;font-size:11px;color:#94a3b8;line-height:1.7;white-space:pre-wrap;border:1px solid #2a2a3a;max-height:300px;overflow-y:auto">\${fullSong}</pre>
      </div>
      <button class="coach-refresh-btn" onclick="window.__TSM_COACH_REFETCH && window.__TSM_COACH_REFETCH()">🔄 Run Again</button>
    \`;
  }`;

const NEW_RENDER = `  // ── Interactive Song Builder State ────────────────────────────────────────
  const songBuilder = {
    lyrics: '',
    options: [],
    hooks: [],
    bridgeSections: [],
    chosenOption: null,
    chosenHook: null,
    chosenBridge: null,
    adlibs: [],
    adlibOutput: ''
  };

  function renderFullSong(data) {
    const { agentData, hooksData, structData } = data;
    songBuilder.lyrics = getContext().lyrics;
    songBuilder.options = agentData?.options || [];
    songBuilder.hooks = hooksData?.hooks || [];
    songBuilder.bridgeSections = structData?.sections?.filter(s => s.type === 'bridge' || s.name?.toLowerCase().includes('bridge')) || [];
    renderStep1();
  }

  // ── STEP 1: Pick a rewrite ─────────────────────────────────────────────────
  function renderStep1() {
    const body = document.getElementById('coach-body');
    body.innerHTML = \`
      <div style="margin-bottom:14px">
        <div style="font-size:10px;color:#7c3aed;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px">Step 1 of 4</div>
        <div style="font-size:14px;font-weight:700;color:#e2e8f0;margin-bottom:4px">🎤 Pick Your Rewrite</div>
        <div style="font-size:12px;color:#64748b">ZAY · RIYA · DJ each took a different angle. Pick the one that hits hardest.</div>
      </div>
      \${songBuilder.options.map((o, i) => \`
        <div style="background:#12121e;border-radius:8px;padding:12px;margin-bottom:10px;border:1px solid #2a2a3a;cursor:pointer;transition:border-color 0.2s"
             onmouseover="this.style.borderColor='#7c3aed'" onmouseout="this.style.borderColor='#2a2a3a'"
             onclick="window.__TSM_PICK_OPTION(\${i})">
          <div style="font-size:10px;color:#6366f1;margin-bottom:6px;font-weight:600">\${o.label}</div>
          <div style="font-size:12px;color:#cbd5e1;line-height:1.6">\${o.text.slice(0,180)}\${o.text.length > 180 ? '...' : ''}</div>
          <div style="margin-top:8px;font-size:11px;color:#7c3aed;font-weight:600">→ Pick This</div>
        </div>
      \`).join('')}
      <button class="coach-refresh-btn" style="background:#1a1a2e;border:1px solid #7c3aed" onclick="window.__TSM_COACH_REFETCH && window.__TSM_COACH_REFETCH()">🔄 Regenerate All</button>
    \`;

    window.__TSM_PICK_OPTION = (i) => {
      songBuilder.chosenOption = songBuilder.options[i];
      renderStep2();
    };
  }

  // ── STEP 2: Pick a hook ────────────────────────────────────────────────────
  function renderStep2() {
    const body = document.getElementById('coach-body');
    body.innerHTML = \`
      <div style="margin-bottom:14px">
        <div style="font-size:10px;color:#7c3aed;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px">Step 2 of 4</div>
        <div style="font-size:14px;font-weight:700;color:#e2e8f0;margin-bottom:4px">🎣 Pick Your Hook</div>
        <div style="font-size:12px;color:#64748b">The hook is what they remember. Pick the one that sticks.</div>
      </div>
      <div style="background:#0d1117;border-radius:6px;padding:8px 10px;margin-bottom:12px;font-size:11px;color:#14f195;border-left:2px solid #14f195">
        ✓ Verse locked: \${(songBuilder.chosenOption?.label || '').split(':')[0]}
      </div>
      \${songBuilder.hooks.map((h, i) => \`
        <div style="background:#12121e;border-radius:8px;padding:10px 12px;margin-bottom:8px;border:1px solid #2a2a3a;cursor:pointer;transition:border-color 0.2s"
             onmouseover="this.style.borderColor='#7c3aed'" onmouseout="this.style.borderColor='#2a2a3a'"
             onclick="window.__TSM_PICK_HOOK(\${i})">
          <div style="font-size:12px;color:#e2e8f0;line-height:1.5">\${i+1}. \${h}</div>
          <div style="margin-top:6px;font-size:11px;color:#7c3aed;font-weight:600">→ Use This Hook</div>
        </div>
      \`).join('')}
      <button style="width:100%;padding:8px;background:transparent;border:1px solid #2a2a3a;border-radius:6px;color:#64748b;cursor:pointer;font-size:12px;margin-top:4px" onclick="renderStep1()">← Back</button>
    \`;

    window.__TSM_PICK_HOOK = (i) => {
      songBuilder.chosenHook = songBuilder.hooks[i];
      renderStep3();
    };
  }

  // ── STEP 3: Pick a bridge ──────────────────────────────────────────────────
  function renderStep3() {
    const body = document.getElementById('coach-body');
    const bridgeOptions = songBuilder.bridgeSections.length > 0
      ? songBuilder.bridgeSections.flatMap(s => s.suggestions || []).slice(0,4)
      : [
          { lyrics: 'This is my time, I\'m taking control — won\'t let anyone bring me down', reason: 'Power shift moment' },
          { lyrics: 'Every scar I earned, every lesson learned — built me for this crown', reason: 'Reflective turn' },
          { lyrics: 'When they counted me out, I turned doubt to a weapon — now watch me', reason: 'Defiant climax' }
        ];

    body.innerHTML = \`
      <div style="margin-bottom:14px">
        <div style="font-size:10px;color:#7c3aed;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px">Step 3 of 4</div>
        <div style="font-size:14px;font-weight:700;color:#e2e8f0;margin-bottom:4px">🌉 Pick Your Bridge</div>
        <div style="font-size:12px;color:#64748b">The bridge is the emotional turn — where the song shifts and lands hardest.</div>
      </div>
      <div style="background:#0d1117;border-radius:6px;padding:8px 10px;margin-bottom:12px;font-size:11px;color:#14f195;border-left:2px solid #14f195">
        ✓ Hook locked: "\${songBuilder.chosenHook?.slice(0,60)}..."
      </div>
      \${bridgeOptions.map((b, i) => \`
        <div style="background:#12121e;border-radius:8px;padding:10px 12px;margin-bottom:8px;border:1px solid #2a2a3a;cursor:pointer;transition:border-color 0.2s"
             onmouseover="this.style.borderColor='#7c3aed'" onmouseout="this.style.borderColor='#2a2a3a'"
             onclick="window.__TSM_PICK_BRIDGE(\${i})">
          <div style="font-size:12px;color:#e2e8f0;line-height:1.5">\${b.lyrics}</div>
          <div style="font-size:10px;color:#64748b;margin-top:4px">\${b.reason || ''}</div>
          <div style="margin-top:6px;font-size:11px;color:#7c3aed;font-weight:600">→ Use This Bridge</div>
        </div>
      \`).join('')}
      <button style="width:100%;padding:8px;background:transparent;border:1px solid #2a2a3a;border-radius:6px;color:#64748b;cursor:pointer;font-size:12px;margin-top:4px" onclick="renderStep2()">← Back</button>
    \`;

    window.__TSM_PICK_BRIDGE = async (i) => {
      songBuilder.chosenBridge = bridgeOptions[i].lyrics;
      await runStep4();
    };
  }

  // ── STEP 4: Add ad-libs + assemble + save ─────────────────────────────────
  async function runStep4() {
    document.getElementById('coach-body').innerHTML =
      '<div class="coach-loading">🎙️ Step 4/4 — ZAY is adding ad-libs...</div>';

    try {
      const adlibRes = await fetch('/api/music/agent/run', {
        method: 'POST', headers: {'Content-Type':'application/json'},
        body: JSON.stringify({
          agent: 'ZAY',
          task: 'add signature ad-libs at every impact line',
          lyrics: songBuilder.chosenOption?.text || songBuilder.lyrics
        })
      });
      const adlibData = await adlibRes.json();
      songBuilder.adlibs = adlibData.ad_libs || [];
      songBuilder.adlibOutput = adlibData.output || songBuilder.chosenOption?.text || '';

      // Assemble full song
      const fullSong = [
        '🎣 HOOK',
        songBuilder.chosenHook || '',
        '',
        '🎤 VERSE',
        songBuilder.adlibOutput,
        '',
        '🌉 BRIDGE',
        songBuilder.chosenBridge || '',
        '',
        songBuilder.adlibs.length ? '🎙️ AD-LIBS: ' + songBuilder.adlibs.join(' · ') : ''
      ].filter(l => l !== undefined).join('\\n');

      // Save to Song Bank
      const bankItem = {
        id: 'tsm-' + Date.now(),
        type: 'Full Song',
        label: 'Full Song — ' + new Date().toLocaleTimeString(),
        lyrics: fullSong,
        hook: songBuilder.chosenHook,
        bridge: songBuilder.chosenBridge,
        adlibs: songBuilder.adlibs,
        created: new Date().toISOString()
      };
      try {
        const bank = JSON.parse(localStorage.getItem('tsm_song_bank') || '[]');
        bank.unshift(bankItem);
        localStorage.setItem('tsm_song_bank', JSON.stringify(bank.slice(0,50)));
        if (window.renderSongBank) window.renderSongBank();
      } catch(_) {}

      renderStep4Complete(fullSong);
    } catch(e) {
      document.getElementById('coach-body').innerHTML =
        \`<div class="coach-loading" style="color:#ef4444">Ad-lib error: \${e.message}</div>\`;
    }
  }

  function renderStep4Complete(fullSong) {
    document.getElementById('coach-body').innerHTML = \`
      <div style="margin-bottom:14px">
        <div style="font-size:10px;color:#14f195;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px">✅ Song Complete</div>
        <div style="font-size:14px;font-weight:700;color:#e2e8f0;margin-bottom:4px">Your Song Is Ready</div>
        <div style="font-size:12px;color:#64748b">Saved to Song Bank. Go to the Song Bank tab to load, export or refine.</div>
      </div>

      \${songBuilder.adlibs.length ? \`
      <div style="margin-bottom:12px">
        <div style="font-size:10px;color:#a78bfa;letter-spacing:.1em;text-transform:uppercase;margin-bottom:6px">🎙️ Ad-libs Added</div>
        <div style="background:#12121e;border-radius:6px;padding:8px 12px;font-size:13px;color:#fbbf24;letter-spacing:.05em">
          \${songBuilder.adlibs.join('  ·  ')}
        </div>
      </div>\` : ''}

      <div style="margin-bottom:12px">
        <div style="font-size:10px;color:#a78bfa;letter-spacing:.1em;text-transform:uppercase;margin-bottom:6px">📋 Full Song</div>
        <pre style="background:#0d0d14;border-radius:8px;padding:12px;font-size:11px;color:#94a3b8;line-height:1.8;white-space:pre-wrap;border:1px solid #2a2a3a;max-height:320px;overflow-y:auto">\${fullSong}</pre>
      </div>

      <button class="coach-refresh-btn" onclick="window.__TSM_COACH_REFETCH && window.__TSM_COACH_REFETCH()">🔄 Start New Song</button>
      <button style="width:100%;padding:10px;background:transparent;border:1px solid #14f195;border-radius:8px;color:#14f195;cursor:pointer;font-size:13px;margin-top:8px" onclick="(function(){
        const tab = document.querySelector('[data-tab=\\'songbank\\']') || document.querySelector('[data-tsm-tab=\\'songbank\\']') || document.querySelector('.tab-btn');
        if(tab) tab.click();
        togglePanel(false);
      })()">📦 Go to Song Bank →</button>
    \`;
  }`;

if (html.includes('function renderFullSong(data) {')) {
  html = html.replace(OLD_RENDER, NEW_RENDER);
  console.log('✅ renderFullSong replaced with interactive step-by-step flow');
} else {
  console.log('❌ Could not find renderFullSong — checking for partial match...');
  const idx = html.indexOf('function renderFullSong');
  console.log('renderFullSong found at index:', idx);
}

fs.writeFileSync(FILE, html);
console.log('✅ Patch written to', FILE);
