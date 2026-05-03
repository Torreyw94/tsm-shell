const fs = require('fs');

// ─── PART 1: Add /api/music/coach route to server.js ───────────────────────
let server = fs.readFileSync('server.js', 'utf8');

const coachRoute = `
// MUSIC COACH — full step-by-step AI guidance
app['post']('/api/music/coach', async (req, res) => {
  const { tab='draft', lyrics='', dna={}, context='', request='' } = req.body;
  const tabGuides = {
    draft: 'The user is in Draft + Analysis mode. Review their lyrics and give specific coaching on: 1) Hook strength, 2) Syllable flow, 3) Imagery. Provide a rewritten example line.',
    revision: 'The user is in Revision Mode. Give precise editing notes: what to cut, what to tighten, suggest a stronger alternate version of their weakest line.',
    generate: 'The user is in Generate mode starting fresh. Suggest 2 creative directions with a sample opening line for each, based on their DNA profile.',
    songbank: 'The user is reviewing their Song Bank. Suggest which piece has the most potential and what one revision would make it release-ready.',
    dna: 'The user is building their Artist DNA profile. Based on what they have, identify gaps in their profile and suggest 3 specific ad-libs and 2 vocab terms that fit their style.',
    studio: 'The user is in Studio Tools. Recommend which tool to use next based on their current lyrics and explain exactly how to use it for maximum impact.'
  };
  const dnaCtx = dna.adlibs?.length ? \`Artist ad-libs: \${dna.adlibs.join(', ')}. Genre: \${dna.genre || 'hip-hop'}. Energy: \${dna.energy || 'balanced'}.\` : '';
  const prompt = \`You are TSM Coach, an expert music production mentor. \${tabGuides[tab] || tabGuides.draft}

\${dnaCtx ? 'Artist DNA: ' + dnaCtx : ''}
\${lyrics ? 'Current lyrics: ' + lyrics.slice(0, 500) : 'No lyrics yet.'}
\${request ? 'Specific request: ' + request : ''}
\${context ? 'Additional context: ' + context : ''}

Return ONLY valid JSON: {"ok":true,"tab":"\${tab}","headline":"Short punchy coaching headline","coaching":"2-3 sentences of specific actionable coaching","example_before":"original line or empty string","example_after":"your improved rewrite or empty string","quick_tips":["tip 1","tip 2","tip 3"],"next_step":"One clear next action for the user","score":{"flow":75,"hooks":80,"imagery":70,"overall":75}}\`;
  try {
    const text = await groqFetch(prompt, 1000);
    return res.json(safeParseGroq(text, {ok:false}));
  } catch(e) {
    if (e.message?.startsWith('RATE_LIMITED:')) return res.status(429).json({ok:false,error:'rate_limited',retry_after:e.message.split(':')[1]});
    return res.json({ok:false,error:e.message});
  }
});
`;

if (!server.includes("/api/music/coach'")) {
  server = server.replace(
    `// CATCH-ALLS — must be last`,
    coachRoute + `// CATCH-ALLS — must be last`
  );
  fs.writeFileSync('server.js', server);
  console.log('✓ /api/music/coach route added to server.js');
} else {
  console.log('- coach route already exists');
}

// ─── PART 2: Fix ActiveModal error in index.html ────────────────────────────
let html = fs.readFileSync('html/music-command/index.html', 'utf8');

// Fix line 2849 — 'ActiveModal' identifier issue
html = html.replace(
  "window.musicModuleActive Modal",
  "window.musicModuleActiveModal"
).replace(
  "window.musicModule ActiveModal",
  "window.musicModuleActiveModal"
).replace(
  "musicModuleActive Modal",
  "musicModuleActiveModal"
);

// Also catch the original unfixed version
html = html.replace(
  "window.musicModule Active =",
  "window.musicModuleActive ="
);
console.log('✓ ActiveModal identifier fixed');

// ─── PART 3: Inject the coaching system before </body> ──────────────────────
const coachScript = `
<script id="tsm-music-coach-system">
(function(){
  if(window.__TSM_COACH__) return;
  window.__TSM_COACH__ = true;

  // ── State ──────────────────────────────────────────────────────────────────
  const coach = {
    open: false,
    loading: false,
    currentTab: 'draft',
    lastCoaching: null,
    autoEnabled: true
  };

  // ── Styles ─────────────────────────────────────────────────────────────────
  const style = document.createElement('style');
  style.textContent = \`
    #tsm-coach-fab {
      position: fixed; bottom: 24px; right: 24px; z-index: 9999;
      width: 52px; height: 52px; border-radius: 50%;
      background: linear-gradient(135deg, #7c3aed, #4f46e5);
      border: none; cursor: pointer; box-shadow: 0 4px 20px rgba(124,58,237,0.5);
      display: flex; align-items: center; justify-content: center;
      font-size: 22px; transition: transform 0.2s; color: white;
    }
    #tsm-coach-fab:hover { transform: scale(1.1); }
    #tsm-coach-fab.loading { animation: coachPulse 1s infinite; }
    @keyframes coachPulse { 0%,100%{opacity:1} 50%{opacity:0.5} }
    #tsm-coach-panel {
      position: fixed; right: -420px; top: 0; bottom: 0; width: 400px;
      background: #0d0d14; border-left: 1px solid #2a2a3a; z-index: 9998;
      overflow-y: auto; transition: right 0.3s ease; padding: 0;
      font-family: var(--font-mono, monospace);
    }
    #tsm-coach-panel.open { right: 0; }
    .coach-header {
      padding: 20px; border-bottom: 1px solid #2a2a3a;
      display: flex; align-items: center; justify-content: space-between;
      background: #0a0a12; position: sticky; top: 0;
    }
    .coach-title { color: #a78bfa; font-size: 11px; letter-spacing: .12em; text-transform: uppercase; font-weight: 600; }
    .coach-close { background: none; border: none; color: #666; cursor: pointer; font-size: 18px; padding: 0; }
    .coach-body { padding: 20px; }
    .coach-headline { color: #e2e8f0; font-size: 15px; font-weight: 700; margin: 0 0 12px; line-height: 1.4; font-family: sans-serif; }
    .coach-text { color: #94a3b8; font-size: 13px; line-height: 1.7; margin-bottom: 16px; font-family: sans-serif; }
    .coach-example { background: #12121e; border-radius: 8px; padding: 12px; margin-bottom: 16px; border: 1px solid #2a2a3a; }
    .coach-ex-label { font-size: 10px; color: #6366f1; letter-spacing: .1em; text-transform: uppercase; margin-bottom: 6px; }
    .coach-ex-before { color: #ef4444; font-size: 13px; text-decoration: line-through; margin-bottom: 8px; line-height: 1.5; font-family: sans-serif; }
    .coach-ex-after { color: #22c55e; font-size: 13px; line-height: 1.5; font-family: sans-serif; }
    .coach-tips { margin-bottom: 16px; }
    .coach-tip { display: flex; gap: 8px; align-items: flex-start; margin-bottom: 8px; font-size: 12px; color: #94a3b8; font-family: sans-serif; line-height: 1.5; }
    .coach-tip-dot { color: #7c3aed; margin-top: 2px; flex-shrink: 0; }
    .coach-next { background: #1a1a2e; border: 1px solid #7c3aed; border-radius: 8px; padding: 12px; margin-bottom: 16px; }
    .coach-next-label { font-size: 10px; color: #7c3aed; letter-spacing: .1em; text-transform: uppercase; margin-bottom: 4px; }
    .coach-next-text { color: #c4b5fd; font-size: 13px; font-family: sans-serif; }
    .coach-scores { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 16px; }
    .coach-score-card { background: #12121e; border-radius: 6px; padding: 10px; text-align: center; }
    .coach-score-val { font-size: 20px; font-weight: 700; color: #a78bfa; }
    .coach-score-lbl { font-size: 10px; color: #64748b; text-transform: uppercase; letter-spacing: .08em; margin-top: 2px; font-family: sans-serif; }
    .coach-refresh-btn {
      width: 100%; padding: 10px; background: #7c3aed; border: none; border-radius: 8px;
      color: white; cursor: pointer; font-size: 13px; font-family: sans-serif;
      margin-bottom: 8px; transition: background 0.2s;
    }
    .coach-refresh-btn:hover { background: #6d28d9; }
    .coach-loading { text-align: center; padding: 40px 20px; color: #6366f1; font-size: 13px; font-family: sans-serif; }
    .coach-inline-tip {
      background: linear-gradient(135deg, #0d0d1a, #12121e);
      border: 1px solid #2a2a3a; border-left: 3px solid #7c3aed;
      border-radius: 0 8px 8px 0; padding: 10px 14px; margin: 8px 0;
      font-size: 12px; color: #94a3b8; font-family: sans-serif; line-height: 1.5;
    }
    .coach-inline-tip strong { color: #a78bfa; }
    #tsm-coach-overlay {
      position: fixed; inset: 0; background: rgba(0,0,0,0.4);
      z-index: 9997; display: none;
    }
    #tsm-coach-overlay.open { display: block; }
  \`;
  document.head.appendChild(style);

  // ── FAB Button ─────────────────────────────────────────────────────────────
  const fab = document.createElement('button');
  fab.id = 'tsm-coach-fab';
  fab.innerHTML = '🎵';
  fab.title = 'AI Coach';
  document.body.appendChild(fab);

  // ── Overlay ────────────────────────────────────────────────────────────────
  const overlay = document.createElement('div');
  overlay.id = 'tsm-coach-overlay';
  document.body.appendChild(overlay);

  // ── Panel ──────────────────────────────────────────────────────────────────
  const panel = document.createElement('div');
  panel.id = 'tsm-coach-panel';
  panel.innerHTML = \`
    <div class="coach-header">
      <span class="coach-title">🎵 TSM AI Coach</span>
      <button class="coach-close" id="coach-close-btn">✕</button>
    </div>
    <div class="coach-body" id="coach-body">
      <div class="coach-loading">Click "Coach Me" to get started, or switch tabs for auto-guidance.</div>
    </div>
  \`;
  document.body.appendChild(panel);

  // ── Toggle ─────────────────────────────────────────────────────────────────
  function togglePanel(open) {
    coach.open = open !== undefined ? open : !coach.open;
    panel.classList.toggle('open', coach.open);
    overlay.classList.toggle('open', coach.open);
    fab.innerHTML = coach.open ? '✕' : '🎵';
  }

  fab.addEventListener('click', () => {
    if (!coach.open) { togglePanel(true); fetchCoaching(); }
    else togglePanel(false);
  });
  overlay.addEventListener('click', () => togglePanel(false));
  document.getElementById('coach-close-btn').addEventListener('click', () => togglePanel(false));

  // ── Get context ────────────────────────────────────────────────────────────
  function getContext() {
    const lyrics = document.getElementById('draft-input')?.value ||
                   document.getElementById('rev-edit')?.value || '';
    const dna = window.STATE?.dna || {};
    const tab = coach.currentTab;
    return { lyrics, dna, tab };
  }

  // ── Fetch coaching ─────────────────────────────────────────────────────────
  async function fetchCoaching(request='') {
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
  }

  // ── Render states ──────────────────────────────────────────────────────────
  function renderLoading() {
    document.getElementById('coach-body').innerHTML =
      '<div class="coach-loading">Analyzing your session...<br><br>⚡ Getting coaching ready</div>';
  }

  function renderError(msg) {
    document.getElementById('coach-body').innerHTML =
      \`<div class="coach-loading" style="color:#ef4444">Coach unavailable<br><small>\${msg}</small></div>\`;
  }

  function renderCoaching(data) {
    const sc = data.score || {};
    document.getElementById('coach-body').innerHTML = \`
      <div style="margin-bottom:16px">
        <div style="font-size:10px;color:#6366f1;letter-spacing:.1em;text-transform:uppercase;margin-bottom:6px">\${data.tab?.toUpperCase() || 'COACHING'} MODE</div>
        <div class="coach-headline">\${data.headline || 'Here is your coaching'}</div>
        <div class="coach-text">\${data.coaching || ''}</div>
      </div>
      \${data.example_before || data.example_after ? \`
      <div class="coach-example">
        <div class="coach-ex-label">Rewrite Example</div>
        \${data.example_before ? \`<div class="coach-ex-before">✗ \${data.example_before}</div>\` : ''}
        \${data.example_after ? \`<div class="coach-ex-after">✓ \${data.example_after}</div>\` : ''}
      </div>\` : ''}
      \${data.quick_tips?.length ? \`
      <div class="coach-tips">
        <div style="font-size:10px;color:#6366f1;letter-spacing:.1em;text-transform:uppercase;margin-bottom:8px">Quick Tips</div>
        \${data.quick_tips.map(t => \`<div class="coach-tip"><span class="coach-tip-dot">▸</span>\${t}</div>\`).join('')}
      </div>\` : ''}
      \${data.next_step ? \`
      <div class="coach-next">
        <div class="coach-next-label">Next Step</div>
        <div class="coach-next-text">\${data.next_step}</div>
      </div>\` : ''}
      \${sc.overall ? \`
      <div class="coach-scores">
        <div class="coach-score-card"><div class="coach-score-val">\${sc.overall}%</div><div class="coach-score-lbl">Overall</div></div>
        <div class="coach-score-card"><div class="coach-score-val">\${sc.flow || 0}%</div><div class="coach-score-lbl">Flow</div></div>
        <div class="coach-score-card"><div class="coach-score-val">\${sc.hooks || 0}%</div><div class="coach-score-lbl">Hooks</div></div>
        <div class="coach-score-card"><div class="coach-score-val">\${sc.imagery || 0}%</div><div class="coach-score-lbl">Imagery</div></div>
      </div>\` : ''}
      <button class="coach-refresh-btn" onclick="window.tsmCoachRefresh()">↺ Refresh Coaching</button>
    \`;
  }

  // ── Inline tips per tab ────────────────────────────────────────────────────
  function updateInlineTip(tab, data) {
    const zoneId = 'coach-inline-' + tab;
    let zone = document.getElementById(zoneId);
    if (!zone) return;
    zone.innerHTML = \`<strong>💡 Coach:</strong> \${data.quick_tips?.[0] || data.coaching?.slice(0,120) || ''}\`;
    zone.style.display = 'block';
  }

  function injectInlineZones() {
    const tabs = ['draft','revision','generate','songbank','dna','studio'];
    tabs.forEach(tab => {
      const panel = document.getElementById('panel-' + tab);
      if (!panel) return;
      const head = panel.querySelector('.section-head');
      if (!head) return;
      if (document.getElementById('coach-inline-' + tab)) return;
      const zone = document.createElement('div');
      zone.id = 'coach-inline-' + tab;
      zone.className = 'coach-inline-tip';
      zone.style.display = 'none';
      zone.textContent = 'AI coaching will appear here when you get guidance.';
      head.after(zone);
    });
  }

  // ── Auto-trigger on tab switch ─────────────────────────────────────────────
  const origSwitchTab = window.switchTab;
  window.switchTab = function(tab) {
    if (origSwitchTab) origSwitchTab(tab);
    coach.currentTab = tab;
    if (coach.autoEnabled) {
      setTimeout(() => {
        if (coach.open) fetchCoaching();
        else {
          // show inline tip on tab switch without opening panel
          fetchCoaching();
        }
      }, 400);
    }
  };

  // ── Public API ─────────────────────────────────────────────────────────────
  window.tsmCoachRefresh = () => fetchCoaching();
  window.tsmCoachAsk = (q) => { togglePanel(true); fetchCoaching(q); };

  // ── Init ───────────────────────────────────────────────────────────────────
  setTimeout(() => {
    injectInlineZones();
    fetchCoaching(); // auto-fire on load
  }, 1500);

})();
</script>
`;

if (!html.includes('tsm-music-coach-system')) {
  html = html.replace('</body>', coachScript + '\n</body>');
  console.log('✓ Coach system injected into index.html');
} else {
  console.log('- Coach system already present');
}

fs.writeFileSync('html/music-command/index.html', html);
console.log('\n✓ All done. Run: node --check server.js && touch html/music-command/index.html && fly deploy --local-only --app tsm-shell');
