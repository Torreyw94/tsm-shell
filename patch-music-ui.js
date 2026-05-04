#!/usr/bin/env node
/**
 * patch-music-ui.js
 * Upgrades the Music Command Center UI to:
 * 1. Use agent-pass-v2 instead of agent-pass
 * 2. Auto-chain hooks + structure + ad-libs after agent pass
 * 3. Wire results into TSM Assistant panel
 * 4. Auto-save complete song to Song Bank
 */

const fs = require('fs');
const FILE = 'html/music-command/index.html';
let html = fs.readFileSync(FILE, 'utf8');

// Backup
fs.writeFileSync(FILE + '.bak.' + Date.now(), html);
console.log('✅ Backup created');

// ── PATCH 1: Upgrade callGroq to use agent-pass-v2 ──────────────────────────
const OLD_FETCH = `const resp = await fetch('/api/music/agent-pass',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prompt: userPrompt || systemPrompt || document.getElementById('draft-input')?.value || ''})});`;

const NEW_FETCH = `const resp = await fetch('/api/music/agent-pass-v2',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prompt: userPrompt || systemPrompt || document.getElementById('draft-input')?.value || ''})});`;

html = html.replace(OLD_FETCH, NEW_FETCH);
console.log('✅ Patch 1: callGroq upgraded to agent-pass-v2');

// ── PATCH 2: Replace the TSM Assistant panel fetch coaching with full chain ──
const OLD_FETCH_COACHING = `  async function fetchCoaching(request='') {
    if (coach.loading) return;
    coach.loading = true;
    fab.classList.add('loading');
    renderLoading();

    const { lyrics, dna, tab } = getContext();
    try {
      const res = await fetch('/api/music/coach', {
        method: 'POST',
        headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ tab, lyrics, dna, request })
      });
      const data = await res.json();
      if (data.ok) {
        coach.lastCoaching = data;
        renderCoaching(data);
        updateInlineTip(tab, data);
      } else {
        renderError(data.error || 'Coach unavailable');
      }
    } catch(e) {
      renderError(e.message);
    } finally {
      coach.loading = false;
      fab.classList.remove('loading');
    }
  }`;

const NEW_FETCH_COACHING = `  async function fetchCoaching(request='') {
    if (coach.loading) return;
    coach.loading = true;
    fab.classList.add('loading');
    renderLoading();

    const { lyrics, dna, tab } = getContext();
    if (!lyrics || lyrics.trim().length < 10) {
      renderError('Paste your lyrics in the Draft tab first, then click Coach Me.');
      coach.loading = false;
      fab.classList.remove('loading');
      return;
    }

    try {
      // Step 1: Agent Pass — 3 rewrites
      document.getElementById('coach-body').innerHTML =
        '<div class="coach-loading">🎤 Step 1/4 — Running Agent Pass...</div>';

      const agentRes = await fetch('/api/music/agent-pass-v2', {
        method: 'POST', headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ prompt: lyrics })
      });
      const agentData = await agentRes.json();

      // Step 2: Generate Hooks
      document.getElementById('coach-body').innerHTML =
        '<div class="coach-loading">🎣 Step 2/4 — Generating Hooks...</div>';

      const hooksRes = await fetch('/api/music/hooks/generate10', {
        method: 'POST', headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ theme: lyrics.slice(0,100), genre: 'hip-hop', mood: 'confident' })
      });
      const hooksData = await hooksRes.json();

      // Step 3: Structure + Bridge
      document.getElementById('coach-body').innerHTML =
        '<div class="coach-loading">🏗️ Step 3/4 — Building Structure & Bridge...</div>';

      const structRes = await fetch('/api/music/structure', {
        method: 'POST', headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ lyrics, mood: 'confident', bpm: 90, context: 'hip-hop anthem' })
      });
      const structData = await structRes.json();

      // Step 4: Ad-libs via ZAY
      document.getElementById('coach-body').innerHTML =
        '<div class="coach-loading">🎙️ Step 4/4 — Adding Ad-libs...</div>';

      const adlibRes = await fetch('/api/music/agent/run', {
        method: 'POST', headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ agent: 'ZAY', task: 'add signature ad-libs at impact points', lyrics })
      });
      const adlibData = await adlibRes.json();

      // Assemble full song
      const bestOption = agentData.options?.[0]?.text || lyrics;
      const topHook = hooksData.hooks?.[0] || '';
      const bridge = structData.sections?.find(s => s.name?.toLowerCase().includes('bridge'))?.description || '';
      const adlibs = adlibData.ad_libs || [];
      const fullSong = [
        topHook ? '🎣 HOOK\n' + topHook : '',
        '\n🎤 VERSE\n' + bestOption,
        bridge ? '\n🌉 BRIDGE\n' + bridge : '',
        adlibs.length ? '\n🎙️ AD-LIBS: ' + adlibs.join(' · ') : ''
      ].filter(Boolean).join('\n');

      // Auto-save to Song Bank
      const bankItem = {
        id: 'tsm-' + Date.now(),
        type: 'Full Song',
        lyrics: fullSong,
        hook: topHook,
        bridge,
        adlibs,
        options: agentData.options || [],
        structure: structData.structure || '',
        scores: { hook: agentData.hook_score || 80, cadence: agentData.cadence_score || 80, lex: agentData.lex_score || 80 },
        created: new Date().toISOString()
      };
      const bank = JSON.parse(localStorage.getItem('tsm_song_bank') || '[]');
      bank.unshift(bankItem);
      localStorage.setItem('tsm_song_bank', JSON.stringify(bank.slice(0,50)));
      if (window.renderSongBank) window.renderSongBank();

      coach.lastCoaching = { ok: true, fullSong, agentData, hooksData, structData, adlibData };
      renderFullSong(coach.lastCoaching);

    } catch(e) {
      renderError(e.message);
    } finally {
      coach.loading = false;
      fab.classList.remove('loading');
    }
  }

  // ── Render full song result ────────────────────────────────────────────────
  function renderFullSong(data) {
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

html = html.replace(OLD_FETCH_COACHING, NEW_FETCH_COACHING);
console.log('✅ Patch 2: TSM Assistant panel upgraded to full song chain');

// ── PATCH 3: Expose refetch globally ────────────────────────────────────────
const OLD_FAB_LISTENER = `  fab.addEventListener('click', () => {
    if (!coach.open) { togglePanel(true); fetchCoaching(); }
    else togglePanel(false);
  });`;

const NEW_FAB_LISTENER = `  fab.addEventListener('click', () => {
    if (!coach.open) { togglePanel(true); fetchCoaching(); }
    else togglePanel(false);
  });
  window.__TSM_COACH_REFETCH = fetchCoaching;`;

html = html.replace(OLD_FAB_LISTENER, NEW_FAB_LISTENER);
console.log('✅ Patch 3: Exposed refetch globally');

// ── PATCH 4: Wire "Get AI Coaching" buttons to open panel + run chain ────────
const OLD_COACHING_BTN = `data-coach-tab="draft" style="font-size:11px;padding:3px 10px;border-radius:20px;border:1px solid rgba(167,139,250,0.5);background:rgba(124,58,237,0.15);color:#a78bfa;cursor:pointer;">&#10022; Get AI Coaching</button>`;
const NEW_COACHING_BTN = `data-coach-tab="draft" onclick="(function(){document.getElementById('tsm-coach-panel').classList.add('open');document.getElementById('tsm-coach-overlay').classList.add('open');window.__TSM_COACH_REFETCH&&window.__TSM_COACH_REFETCH();})()" style="font-size:11px;padding:3px 10px;border-radius:20px;border:1px solid rgba(167,139,250,0.5);background:rgba(124,58,237,0.15);color:#a78bfa;cursor:pointer;">&#9835; Build Full Song</button>`;

html = html.replace(OLD_COACHING_BTN, NEW_COACHING_BTN);
console.log('✅ Patch 4: "Get AI Coaching" button wired to full song chain');

fs.writeFileSync(FILE, html);
console.log('\n🚀 All patches applied to', FILE);
console.log('Test: node server.js then open http://localhost:8080/music');
