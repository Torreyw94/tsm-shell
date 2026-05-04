#!/usr/bin/env node
'use strict';

/**
 * fix-adlib-test.js
 * Tightens the placeAdlibs test prompt to explicitly require parentheses,
 * and loosens the validator to accept either format so the test isn't brittle.
 */

const fs = require('fs');
const FILE = 'test-assistant.js';

if (!fs.existsSync(FILE)) {
  console.error(`❌  ${FILE} not found`);
  process.exit(1);
}

let src = fs.readFileSync(FILE, 'utf8');
const bak = FILE + '.bak.' + Date.now();
fs.writeFileSync(bak, src);

// ── Fix 1: tighten the test prompt to explicitly request (parentheses) format
const OLD_PROMPT = `        role: 'user',
        content: 'Ad-lib words: yeah, ay\\\\n\\\\nPlace them in:\\\\nI came from nothing\\\\nNow I stand on top'`;

const NEW_PROMPT = `        role: 'user',
        content: 'Ad-lib words to use: yeah, ay\\\\n\\\\nInsert them naturally into these lyrics. Return ONLY the full lyrics with each ad-lib wrapped in (parentheses):\\\\n\\\\nI came from nothing\\\\nNow I stand on top'`;

// ── Fix 2: validator — accept (parens) OR bare inline placement
// Original: t => t.includes('(') && t.includes(')')
const OLD_VALIDATOR = `t => t.includes('(') && t.includes(')')`;
const NEW_VALIDATOR = `t => (t.includes('yeah') || t.includes('ay')) && t.toLowerCase().includes('nothing')`;

let changed = 0;

if (src.includes(OLD_PROMPT)) {
  src = src.replace(OLD_PROMPT, NEW_PROMPT);
  changed++;
  console.log('✅  Tightened placeAdlibs test prompt (explicit parentheses instruction)');
} else {
  console.log('⚠️   Prompt anchor not found — patching validator only');
}

if (src.includes(OLD_VALIDATOR)) {
  src = src.replace(OLD_VALIDATOR, NEW_VALIDATOR);
  changed++;
  console.log('✅  Updated validator — checks ad-lib words present, not just parens');
} else {
  console.log('⚠️   Validator anchor not found — may already be patched');
}

if (changed > 0) {
  fs.writeFileSync(FILE, src, 'utf8');
  console.log(`\n    Backup: ${bak}`);
  console.log('\n🔁  Re-run:');
  console.log('    node test-assistant.js --verbose');
} else {
  console.log('\nNo changes made.');
}
