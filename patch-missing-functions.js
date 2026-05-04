#!/usr/bin/env node
'use strict';

/**
 * patch-contextual-coaching.js
 * 
 * WHAT THIS FIXES:
 * 1. Replaces generic tsmStudioGuide() on all coach buttons with
 *    tab-specific coaching functions (one per tab)
 * 2. Adds a coaching button to the Draft tab (currently has none)
 * 3. Makes the TSM Assistant context-aware — it knows which tab
 *    the user is on and gives relevant next-step guidance
 * 4. Adds proactive assistant nudges when user lands on each tab
 *
 * Usage: node patch-contextual-coaching.js
 *        node patch-contextual-coaching.js --dry-run
 */

const fs = require('fs');
const FILE = 'html/music-command/index.html';
const DRY  = process.argv.includes('--dry-run');

if (!fs.existsSync(FILE)) {
  console.error(`❌  ${FILE} not found — run from repo root`);
  process.exit(1);
}

let html = fs.readFileSync(FILE, 'utf8');
const bak = FILE + '.bak.' + Date.now();
if (!DRY) { fs.writeFileSync(bak, html); console.log(`✅  Backup → ${bak}`); }
else console.log('🔍  DRY RUN\n');

let patches = 0;

function patch(label, anchor, insert, { before = false, guard = null } = {}) {
  if (guard && html.includes(guard)) { console.log(`⏭   ${label} — already present`); return; }
  if (!html.includes(anchor)) { console.warn(`⚠️   ${label} — anchor not found`); return; }
  const i = html.indexOf(anchor);
  const pos = before ? i : i + anchor.length;
  html = html.slice(0, pos) + insert + html.slice(pos);
  patches++;
  console.log(`✅  ${label}`);
}

// ─── 1. Context-aware coach functions (one per tab) ──────────────────────────

const COACH_FUNCTIONS = `

// ── Context-aware tab coaching (patch-contextual-coaching.js) ────────────────

const TAB_COACH_PROMPTS = {
  draft: {
    title: 'Draft + Analysis Coach',
    sys: 'You are TSM\\'s AI music coach guiding an artist through the Draft & Analysis tab.',
    prompt: (dna) => \`The artist is on the DRAFT TAB. Give them a sharp, specific 5-step coaching guide for this exact workflow:\\n\\n\`
      + \`1. How to paste and frame their draft for the best analysis\\n\`
      + \`2. Which agent to pick (ZAY=flow, DJ=structure, RIYA=imagery) and when\\n\`
      + \`3. How to read the 5 scores (Hook Identity, Cadence, Lexical, Structure, DNA Match)\\n\`
      + \`4. How to use the quick-action buttons (↑ Street, ✂ Tighten, ❤ Emotion, etc.)\\n\`
      + \`5. When to iterate vs when to move to Revision\\n\\n\`
      + (dna ? \`Artist DNA context:\\n\` + dna : \`No DNA loaded yet — recommend they set it up first.\`)
  },
  revision: {
    title: 'Revision Mode Coach',
    sys: 'You are TSM\\'s AI music coach guiding an artist through Revision Mode.',
    prompt: (dna) => \`The artist is on the REVISION TAB. Give sharp coaching on:\\n\\n\`
      + \`1. What goes in Box 1 (current draft) vs Box 2 (edit instructions) — common mistakes\\n\`
      + \`2. How to write a Focused Request that gets precise results\\n\`
      + \`3. How to use Box 3 (protect lines) — what to protect and why\\n\`
      + \`4. How to use Box 4 output styles — give 3 example style combos\\n\`
      + \`5. How to pick between 3 returned options and iterate\\n\\n\`
      + (dna ? \`Artist DNA:\\n\` + dna : \`Tip: fill Artist DNA first so revisions match their voice.\`)
  },
  gen: {
    title: 'Generate Tab Coach',
    sys: 'You are TSM\\'s AI music coach guiding an artist through the Generate tab.',
    prompt: (dna) => \`The artist is on the GENERATE TAB. Coach them on:\\n\\n\`
      + \`1. Which "What to Generate" option to start with and why (Hook Options first — here\\'s why)\\n\`
      + \`2. How Tone/Feel changes the output — give 2 contrasting examples\\n\`
      + \`3. How to write a Concept that gets specific, usable output (not generic)\\n\`
      + \`4. When to use "Generate from DNA" vs plain "Generate"\\n\`
      + \`5. The fastest path from Generate → Revision → Song Bank\\n\\n\`
      + (dna ? \`Artist DNA:\\n\` + dna : \`DNA not loaded — outputs will be generic until DNA is set.\`)
  },
  bank: {
    title: 'Song Bank Coach',
    sys: 'You are TSM\\'s AI music coach guiding an artist through the Song Bank.',
    prompt: (dna) => \`The artist is on the SONG BANK TAB. Coach them on:\\n\\n\`
      + \`1. How to use the bank as a full song assembly workflow (not just storage)\\n\`
      + \`2. How to combine a saved Hook + Verse + Bridge into a complete song\\n\`
      + \`3. When to use "Learn from Song" to feed a saved piece into Artist DNA\\n\`
      + \`4. How to export and format for their DAW or producer\\n\`
      + \`5. How to A/B test saved options with their team\`
  },
  dna: {
    title: 'Artist DNA Coach',
    sys: 'You are TSM\\'s AI music coach helping an artist build their DNA profile.',
    prompt: () => \`The artist is on the ARTIST DNA TAB — the most important setup step. Coach them:\\n\\n\`
      + \`1. Why DNA matters — how it changes every single output (be specific about the difference)\\n\`
      + \`2. What to put in Ad-libs (give 5 example ad-lib styles for different artist types)\\n\`
      + \`3. What to put in Vocabulary & Slang (examples: regional, era-specific, personal)\\n\`
      + \`4. How to write Flow Patterns that actually help the AI (bad example vs good example)\\n\`
      + \`5. How Themes & Motifs work as a creative lens — give 3 theme examples and their effect\`
  },
  studiotools: {
    title: 'Studio Tools Coach',
    sys: 'You are TSM\\'s AI music coach guiding an artist through Studio Tools.',
    prompt: (dna) => \`The artist is on the STUDIO TOOLS TAB. Give a practical guide:\\n\\n\`
      + \`1. Best order to use the tools for a song that\\'s 80% done vs just starting\\n\`
      + \`2. Rhyme Engine: how to use it beyond basic rhymes (near-rhymes, slant, multi-syllable)\\n\`
      + \`3. Syllable Counter + Replay Optimizer: how to use them together to tighten a hook\\n\`
      + \`4. Contrast Builder: when to use it and what makes a good dark→triumphant transition\\n\`
      + \`5. The 3 tools most artists skip but shouldn\\'t (and why)\\n\\n\`
      + (dna ? \`Artist DNA:\\n\` + dna : '')
  }
};

function tsmTabCoach(tab) {
  const cfg = TAB_COACH_PROMPTS[tab] || TAB_COACH_PROMPTS.studiotools;
  const dnaCtx = buildDNAContext ? buildDNAContext() : '';
  
  const sys = cfg.sys + (dnaCtx ? '\\n\\nARTIST DNA:\\n' + dnaCtx : '') 
    + '\\n\\nBe direct, specific, and practical. Use numbered steps. No filler. Max 350 words.';
  const prompt = cfg.prompt(dnaCtx);

  // Show output in the assistant panel
  const assistantPanel = document.getElementById('tsm-assistant-body') 
    || document.getElementById('assistant-output')
    || document.getElementById('tool-out-content');

  const assistantWrap = document.getElementById('tsm-assistant-wrap')
    || document.getElementById('assistant-wrap');

  if (assistantWrap) assistantWrap.style.display = 'block';

  // Try to use the tool output area on Studio Tools tab as fallback
  const outArea = document.getElementById('tool-output-area');
  const outTitle = document.getElementById('tool-out-title');
  const outContent = document.getElementById('tool-out-content');

  // Show loading state
  if (outTitle) outTitle.textContent = cfg.title;
  if (outContent) outContent.textContent = 'Getting coaching for this step...';
  if (outArea) { outArea.style.display = 'block'; outArea.scrollIntoView({ behavior: 'smooth' }); }
  if (typeof showNotif === 'function') showNotif('🎓 Loading coaching for this tab...');

  callGroq(sys, prompt, 'dna-loading', function(text) {
    // Push to assistant chat if available
    if (typeof tsmAssistantSpeak === 'function') {
      tsmAssistantSpeak(text);
    } else if (outContent) {
      outContent.textContent = text;
    }
    STATE.lastOutput.tool = text;
    if (typeof showNotif === 'function') showNotif('🎓 ' + cfg.title + ' ready');
    // Switch to studio tools tab to show output if not already there
    if (tab !== 'studiotools' && outArea) {
      switchTab('studiotools');
    }
  });
}

// Context-aware assistant: reads which tab is active and gives relevant nudge
function tsmAssistantContextCheck() {
  const activeTab = STATE.activeTab || document.querySelector('.tab-btn.active, .nav-tab.active, [data-tab].active')?.dataset?.tab || 'draft';
  
  const nudges = {
    draft:       '📝 **Draft tab** — Paste your lyrics and hit **Run Agent Pass**. Pick ZAY for flow, DJ for structure, RIYA for imagery. Click **♫ Get Coaching** for a full walkthrough.',
    revision:    '✂️ **Revision tab** — Box 1 = what to change, Box 2 = instructions, Box 3 = protect, Box 4 = output styles. Click **✦ Get AI Coaching** for a step-by-step guide.',
    gen:         '✨ **Generate tab** — Start with **Hook Options** from the dropdown. Add your concept. Click **Generate from DNA** if your profile is loaded.',
    bank:        '📂 **Song Bank** — Your saved pieces live here. Load any card back into Draft or Revision. Use **Learn from Song** to feed it into your DNA.',
    dna:         '🧬 **Artist DNA** — This shapes EVERYTHING. Add your ad-libs, slang, flow patterns, and themes first. Click **✦ Get AI Coaching** to see exactly what to put in each field.',
    studiotools: '🛠 **Studio Tools** — Use Rhyme Engine → Syllable Counter → Replay Optimizer in sequence to tighten a hook. Click **♫ AI Tool Guide** for the full playbook.'
  };

  return nudges[activeTab] || nudges.draft;
}

// Override tsmStudioGuide to be tab-aware
const _origStudioGuide = typeof tsmStudioGuide === 'function' ? tsmStudioGuide : null;
function tsmStudioGuide() {
  const activeTab = STATE.activeTab 
    || document.querySelector('.tab-btn.active, [data-tab].active')?.dataset?.tab 
    || 'studiotools';
  tsmTabCoach(activeTab);
}
`;

patch(
  'Context-aware coach functions',
  'function tsmAssistantUpdate(',
  COACH_FUNCTIONS + '\n',
  { before: true, guard: 'TAB_COACH_PROMPTS' }
);

// ─── 2. Proactive tab-switch nudges ──────────────────────────────────────────
// Hook into switchTab() to fire a contextual assistant message on every tab change

const SWITCHTAB_HOOK = `

// Proactive coaching nudge on tab switch
const _origSwitchTab = switchTab;
function switchTab(tab) {
  _origSwitchTab(tab);
  STATE.activeTab = tab;
  // Update assistant with context nudge after short delay (let tab render first)
  setTimeout(function() {
    const nudge = tsmAssistantContextCheck ? tsmAssistantContextCheck() : null;
    if (!nudge) return;
    const msgEl = document.getElementById('tsm-assistant-msg') 
      || document.getElementById('assistant-msg')
      || document.getElementById('assistant-latest');
    if (msgEl) {
      msgEl.innerHTML = nudge.replace(/\\*\\*(.*?)\\*\\*/g, '<strong>$1</strong>');
    }
    // Also update the bottom assistant panel text if it exists
    const botMsg = document.querySelector('#tsm-assistant-body p, #tsm-assistant-body div');
    if (botMsg) botMsg.innerHTML = nudge.replace(/\\*\\*(.*?)\\*\\*/g, '<strong>$1</strong>');
  }, 150);
}
`;

patch(
  'Proactive tab-switch nudges',
  '// ── Context-aware tab coaching',
  SWITCHTAB_HOOK + '\n',
  { before: true, guard: '_origSwitchTab' }
);

// ─── 3. Wire each "Get AI Coaching" button to its tab-specific function ───────
// The buttons currently call tsmStudioGuide() generically.
// We update each onclick to call tsmTabCoach('tabname') directly.

const COACH_BUTTON_REPLACEMENTS = [
  // Revision tab coach button
  {
    label: 'Wire Revision coach button',
    // Look for the coach button near "Revision Mode" heading
    old: `♫ TSM Coach · Revision Mode✦ Get AI Coaching`,
    // We can't easily change onclick in rendered text, so we target the JS onclick pattern
    // Instead patch the HTML button onclick attributes
  }
];

// More reliable: find and replace onclick="tsmStudioGuide()" on coach buttons
// by matching the button HTML pattern near each tab section

const TAB_BUTTON_PATCHES = [
  { 
    label: 'Revision coach button → tsmTabCoach',
    old:  `data-coach-tab="revision" onclick="tsmStudioGuide()"`,
    neo:  `data-coach-tab="revision" onclick="tsmTabCoach('revision')"`
  },
  {
    label: 'Generate coach button → tsmTabCoach',
    old:  `data-coach-tab="gen" onclick="tsmStudioGuide()"`,
    neo:  `data-coach-tab="gen" onclick="tsmTabCoach('gen')"`
  },
  {
    label: 'Song Bank coach button → tsmTabCoach',
    old:  `data-coach-tab="bank" onclick="tsmStudioGuide()"`,
    neo:  `data-coach-tab="bank" onclick="tsmTabCoach('bank')"`
  },
  {
    label: 'Artist DNA coach button → tsmTabCoach',
    old:  `data-coach-tab="dna" onclick="tsmStudioGuide()"`,
    neo:  `data-coach-tab="dna" onclick="tsmTabCoach('dna')"`
  },
  {
    label: 'Studio Tools coach button → tsmTabCoach',
    old:  `data-coach-tab="studiotools" onclick="tsmStudioGuide()"`,
    neo:  `data-coach-tab="studiotools" onclick="tsmTabCoach('studiotools')"`
  },
];

for (const { label, old, neo } of TAB_BUTTON_PATCHES) {
  if (html.includes(old)) {
    html = html.split(old).join(neo);
    patches++;
    console.log(`✅  ${label}`);
  } else {
    // Try alternate pattern without data-coach-tab
    console.log(`⏭   ${label} — button pattern not found (may use different attribute)`);
  }
}

// ─── 4. Add coaching button to Draft tab (currently missing one) ──────────────

const DRAFT_COACH_BUTTON = ` <button onclick="tsmTabCoach('draft')" `
  + `style="font-size:11px;padding:3px 10px;border-radius:20px;`
  + `border:1px solid rgba(167,139,250,0.5);background:rgba(124,58,237,0.15);`
  + `color:#a78bfa;cursor:pointer;margin-left:8px;">♫ Get Coaching</button>`;

// Anchor: the Draft tab heading — "♫ TSM Coach · Draft + Analysis♫ Build Full Song"
patch(
  'Add coaching button to Draft tab',
  '♫ TSM Coach · Draft + Analysis',
  '',
  { guard: "tsmTabCoach('draft')" }
);

// If the button isn't embedded via the above, inject it via the Build Full Song anchor
if (!html.includes("tsmTabCoach('draft')")) {
  const draftAnchor = '♫ Build Full Song';
  if (html.includes(draftAnchor)) {
    html = html.replace(
      draftAnchor,
      draftAnchor + DRAFT_COACH_BUTTON
    );
    patches++;
    console.log('✅  Draft tab coaching button added');
  } else {
    console.warn('⚠️   Draft tab anchor not found — add manually');
  }
}

// ─── 5. Update TSM Assistant welcome to be action-oriented ───────────────────

const OLD_WELCOME = `👋 Welcome! Start by clicking **1 · DNA** above to set your artist style. This makes every AI output sound like you.`;
const NEW_WELCOME = `👋 Welcome to Music Command. Click any tab and I'll guide you through it. Start with 🧬 **Artist DNA** to make every output sound like you — or jump to ✏️ **Draft** to paste your lyrics now.`;

if (html.includes(OLD_WELCOME)) {
  html = html.split(OLD_WELCOME).join(NEW_WELCOME);
  patches++;
  console.log('✅  Updated TSM Assistant welcome message');
} else {
  console.log('⏭   Welcome message already updated or uses different text');
}

// ─── Write ────────────────────────────────────────────────────────────────────

if (DRY) {
  console.log(`\n🔍  Dry run — ${patches} patch(es) would apply`);
} else {
  fs.writeFileSync(FILE, html, 'utf8');
  console.log(`\n✅  ${patches} patch(es) applied → ${FILE}`);
  console.log(`    Backup: ${bak}`);
  console.log('\n🔁  Test before deploying:');
  console.log('    node test-assistant.js --verbose');
  console.log('\n🚀  Then deploy:');
  console.log('    fly deploy -a tsm-shell');
}
