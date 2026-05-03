#!/usr/bin/env node
/**
 * fix-guide-clarity.js
 * Replaces all 6 guide bars with hyper-specific, action-oriented content
 * that tells users EXACTLY what to do at each step — no vagueness
 */

const fs = require('fs');
const html_path = 'html/music-command/index.html';
let content = fs.readFileSync(html_path, 'utf8');

// New guide bar content — ultra specific per panel
const PANELS = {
  'tsm-bar-draft': {
    tab: 'draft',
    label: 'Draft + Analysis',
    startHere: '👇 START HERE: Paste your lyrics into the large text area below labeled "PASTE YOUR DRAFT"',
    steps: [
      '① Paste your hook, verse, or full draft into the big text box below',
      '② Type what you want in "Focused Request" — e.g. "Make the hook stickier" or "Tighten the cadence"',
      '③ Pick an Agent (ZAY = flow, DJ = structure, RIYA = imagery) then click RUN AGENT PASS',
      '④ Review your scores: Hook Identity, Cadence Control, Lexical Sharpness, Structure Health, DNA Match',
      '⑤ Click ITERATE AGAIN to improve — repeat until score rises — then click SAVE TO BANK',
    ]
  },
  'tsm-bar-revision': {
    tab: 'revision',
    label: 'Revision Mode',
    startHere: '👇 START HERE: Paste the draft you want to revise into Box 1 "Current Draft — What You Want Revised"',
    steps: [
      '① Box 1: Paste the draft lines you want changed',
      '② Box 2: Write exact edit instructions — "Add pre-hook", "Make darker", "Tighten syllables"',
      '③ Box 3: Paste lines that must NOT change — the agent will protect these exactly',
      '④ Box 4: List 3 output styles you want back — e.g. "street anthem / emotional trap / live energy"',
      '⑤ Click RUN REVISION MODE — pick the strongest of the 3 options — click SAVE TO BANK',
    ]
  },
  'tsm-bar-generate': {
    tab: 'generate',
    label: 'Generate',
    startHere: '👇 START HERE: Pick what to generate from the "What to Generate" dropdown — start with "Hook Options"',
    steps: [
      '① Dropdown: pick Hook Options, Full Verse, Bridge, Ad-lib Sheet, or Full Song Skeleton',
      '② Tone/Feel: pick the mood — Triumphant, Dark, Street, Melodic, Hyper, Vulnerable',
      '③ Concept box: describe your idea — "Phoenix rising, pressure became power"',
      '④ Reference Lines (optional): paste 1-2 of your own lines so AI matches your voice',
      '⑤ Click GENERATE or GENERATE FROM DNA — then SAVE TO BANK or REFINE IN REVISION',
    ]
  },
  'tsm-bar-songbank': {
    tab: 'songbank',
    label: 'Song Bank',
    startHere: '👇 Your saved songs appear as cards below — click any card to load it back into Draft or Revision',
    steps: [
      '① Every time you click SAVE TO BANK in Draft or Revision, it appears here as a card',
      '② Click LOAD on any card to bring it back into the Draft panel for more work',
      '③ Click LEARN FROM SONG to feed that song into your Artist DNA profile',
      '④ Click EXPORT TXT to download the full song as a text file for your DAW or notes',
      '⑤ Use the + New button top-right to start a fresh song from scratch',
    ]
  },
  'tsm-bar-artistdna': {
    tab: 'artistdna',
    label: 'Artist DNA',
    startHere: '👇 START HERE: Add your signature ad-libs in the SIGNATURE AD-LIBS box — these get woven into every output',
    steps: [
      '① Add your ad-libs: yeah, uh, let\'s go, ay — these appear automatically in every generation',
      '② Add Vocabulary & Slang words that are native to your voice — pressure, on sight, locked in',
      '③ Add Flow Patterns — triplets on the 3, pause-punch delivery, double-time',
      '④ Add Themes & Motifs — Phoenix rising, loyalty, perseverance — AI uses these as your creative lens',
      '⑤ Click ANALYZE MY DNA to lock in your profile — all future generations will match your style',
    ]
  },
  'tsm-bar-studiotools': {
    tab: 'studiotools',
    label: 'Studio Tools',
    startHere: '👇 START HERE: Use the tools above to polish your finalized lyrics before export',
    steps: [
      '① GENERATE 10 HOOKS: batch-generates 10 hook variants for A/B testing with your team',
      '② EXPORT TXT: packages your full song (hook + verse + bridge + ad-libs) as a clean text file',
      '③ SAVE ARTIST SESSION: saves your entire workspace — DNA, songs, and settings',
      '④ Metaphor Lab: paste a theme and get 5 metaphor options to elevate your imagery',
      '⑤ When ready — set your monetization tier and export for your DAW session',
    ]
  }
};

function makeGuideBar(sentinel_key, data) {
  const stepsHtml = data.steps.map(step =>
    `<div style="display:flex;gap:8px;font-size:12px;color:rgba(255,255,255,0.7);padding:6px 10px;border-radius:6px;background:rgba(255,255,255,0.04);border-left:2px solid rgba(124,58,237,0.4);margin-bottom:5px">` +
    `<span>${step}</span></div>`
  ).join('');

  return `\n      <div class="tsm-guide-bar" data-tsm-tab="${data.tab}" style="margin:0 0 16px;border-radius:10px;border:1px solid rgba(124,58,237,0.35);background:rgba(20,10,40,0.6);font-size:13px;overflow:hidden;">` +
    `<div style="display:flex;align-items:center;justify-content:space-between;padding:8px 14px;background:rgba(124,58,237,0.14);border-bottom:1px solid rgba(124,58,237,0.2);">` +
    `<span style="font-size:11px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:#a78bfa">&#9835; TSM Coach &middot; ${data.label}</span>` +
    `<button data-coach-tab="${data.tab}" style="font-size:11px;padding:3px 10px;border-radius:20px;border:1px solid rgba(167,139,250,0.5);background:rgba(124,58,237,0.15);color:#a78bfa;cursor:pointer;">&#10022; Get AI Coaching</button>` +
    `</div>` +
    `<div style="padding:10px 14px;">` +
    `<div style="background:rgba(20,241,149,0.07);border:1px solid rgba(20,241,149,0.25);border-radius:8px;padding:8px 12px;margin-bottom:10px;font-size:12.5px;color:#14f195;font-weight:600;">${data.startHere}</div>` +
    stepsHtml +
    `<div class="tsm-ai-out" style="display:none;margin-top:8px;padding-top:8px;border-top:1px solid rgba(255,255,255,0.07);font-size:12px;color:rgba(255,255,255,.8);line-height:1.7"></div>` +
    `</div>` +
    `</div>`;
}

// Replace each guide bar
let replacedCount = 0;
for (const [sentinel_key, data] of Object.entries(PANELS)) {
  const sentinel = `<!-- ${sentinel_key} -->`;
  const sentinelIdx = content.indexOf(sentinel);
  if (sentinelIdx === -1) {
    console.log(`WARNING: ${sentinel} not found`);
    continue;
  }

  // Find the start of the div after the sentinel
  const divStart = content.indexOf('<div', sentinelIdx);
  if (divStart === -1) continue;

  // Find the matching closing </div> for this guide bar
  let depth = 0;
  let i = divStart;
  let divEnd = -1;
  while (i < content.length) {
    if (content.slice(i, i+4) === '<div') depth++;
    else if (content.slice(i, i+6) === '</div>') {
      depth--;
      if (depth === 0) { divEnd = i + 6; break; }
    }
    i++;
  }

  if (divEnd === -1) {
    console.log(`WARNING: could not find end of guide bar for ${sentinel_key}`);
    continue;
  }

  const newBar = makeGuideBar(sentinel_key, data);
  content = content.slice(0, sentinelIdx) +
            sentinel +
            newBar +
            content.slice(divEnd);
  console.log(`✓ Replaced guide bar: ${sentinel_key}`);
  replacedCount++;
}

fs.writeFileSync(html_path, content, 'utf8');
console.log(`\n✓ Done — ${replacedCount}/6 guide bars replaced`);
console.log('Deploy: fly deploy --local-only --app tsm-shell');
