#!/usr/bin/env node
'use strict';

/**
 * fix-syntax-error.js
 * 1. Shows exactly what's at the error line in the HTML
 * 2. Fixes broken string escaping in TAB_COACH_PROMPTS
 *    (single-quoted JS strings containing \' — terminates the string early)
 *
 * Usage: node fix-syntax-error.js
 */

const fs = require('fs');
const FILE = 'html/music-command/index.html';

if (!fs.existsSync(FILE)) { console.error(`❌  ${FILE} not found`); process.exit(1); }

let html = fs.readFileSync(FILE, 'utf8');
const lines = html.split('\n');

// ─── Diagnose: show context around line 3479 ─────────────────────────────────
console.log('\n── Diagnosis: lines 3474–3484 ───────────────────────────────────');
for (let i = 3473; i <= Math.min(3483, lines.length - 1); i++) {
  const marker = i === 3478 ? ' ◄ ERROR' : '';
  console.log(`${String(i + 1).padStart(5)}  ${lines[i]}${marker}`);
}

// ─── Fix: rewrite TAB_COACH_PROMPTS strings safely ───────────────────────────
// The bug: Node wrote  'You are TSM\'s ...'  into the HTML.
// Inside a JS single-quoted string, \' is valid BUT some parsers choke on it
// depending on context. Safest fix: replace all \' inside JS strings with
// the Unicode escape \u0027 OR switch the outer quotes to double quotes.
//
// Strategy: find the TAB_COACH_PROMPTS block and replace every  \'  with  \u2019
// (right single quotation mark — visually identical, never breaks JS strings)

console.log('\n── Fix: escaping in TAB_COACH_PROMPTS ───────────────────────────');

const BLOCK_START = 'const TAB_COACH_PROMPTS = {';
const BLOCK_END   = '};\n\nfunction tsmTabCoach(';

if (!html.includes(BLOCK_START)) {
  console.error('❌  TAB_COACH_PROMPTS block not found — check patch applied correctly');
  process.exit(1);
}

const startIdx = html.indexOf(BLOCK_START);
const endIdx   = html.indexOf(BLOCK_END, startIdx);

if (endIdx === -1) {
  console.error('❌  Could not find end of TAB_COACH_PROMPTS block');
  process.exit(1);
}

const before = html.slice(0, startIdx);
let   block  = html.slice(startIdx, endIdx + BLOCK_END.length);
const after  = html.slice(endIdx + BLOCK_END.length);

// Count issues before fix
const badEscapes = (block.match(/\\'/g) || []).length;
console.log(`   Found ${badEscapes} instances of \\' in the block`);

// Fix 1: replace \' with the actual apostrophe character (safest for display strings)
block = block.replace(/\\'/g, "\u2019");

// Fix 2: also fix any unterminated template literal backtick escapes
// Pattern: \` inside a single-quoted string — should just be a backtick
block = block.replace(/\\`/g, '`');

// Fix 3: ensure the _origSwitchTab reassignment doesn't shadow itself
// (can cause: "Cannot access 'switchTab' before initialization" in strict mode)
const SHADOW_BUG = 'const _origSwitchTab = switchTab;\nfunction switchTab(tab) {';
const SHADOW_FIX = 'var _origSwitchTab = switchTab;\nfunction switchTab(tab) {';
if (html.includes(SHADOW_BUG)) {
  html = html.replace(SHADOW_BUG, SHADOW_FIX);
  console.log("✅  Fixed const→var for _origSwitchTab (hoisting fix)");
}

html = before + block + after;

// Also fix the same escaping issue anywhere else in our patched sections
const PATCH_MARKERS = [
  '// ── Generated functions (patch-missing-functions.js)',
  '// ── Context-aware tab coaching (patch-contextual-coaching.js)'
];

for (const marker of PATCH_MARKERS) {
  if (!html.includes(marker)) continue;
  const mStart = html.indexOf(marker);
  // Fix \' in the 2000 chars after each marker
  const chunk  = html.slice(mStart, mStart + 3000);
  const fixed  = chunk.replace(/\\'/g, "\u2019");
  html = html.slice(0, mStart) + fixed + html.slice(mStart + 3000);
}

// ─── Validate: basic JS string balance check around error zone ───────────────
console.log('\n── Validation: checking string balance around fix ───────────────');
const fixedLines = html.split('\n');
const checkStart = Math.max(0, 3470);
const checkEnd   = Math.min(fixedLines.length, 3500);
let   singleOpen = false;
let   issues     = 0;

for (let i = checkStart; i < checkEnd; i++) {
  const line = fixedLines[i];
  for (let c = 0; c < line.length; c++) {
    if (line[c] === "'" && (c === 0 || line[c-1] !== '\\')) {
      singleOpen = !singleOpen;
    }
  }
  // Each line should end in a balanced state for single-line strings
  // (multiline template literals aside — just flag suspicious lines)
  if (line.includes("'") && line.trim().startsWith("'") && !line.trim().endsWith("'") && !line.includes('//')) {
    console.log(`   ⚠️   Line ${i+1} may have unbalanced quote: ${line.trim().slice(0,60)}`);
    issues++;
  }
}
if (issues === 0) console.log('✅  No obvious string balance issues found in range');

// ─── Write ────────────────────────────────────────────────────────────────────
const bak = FILE + '.bak.' + Date.now();
fs.writeFileSync(bak, fs.readFileSync(FILE));
fs.writeFileSync(FILE, html, 'utf8');
console.log(`\n✅  File written (backup: ${bak})`);

// Show fixed lines around the error zone
console.log('\n── Fixed lines 3474–3484 ────────────────────────────────────────');
const newLines = html.split('\n');
for (let i = 3473; i <= Math.min(3483, newLines.length - 1); i++) {
  console.log(`${String(i + 1).padStart(5)}  ${newLines[i]}`);
}

console.log('\n── Next steps ───────────────────────────────────────────────────');
console.log('node test-assistant.js --verbose');
console.log('fly deploy -a tsm-shell');
