#!/usr/bin/env node
'use strict';

/**
 * fix-model.js
 * Replaces the decommissioned llama3-8b-8192 model with llama-3.3-70b-versatile
 * in both the HTML app and the test script.
 *
 * Usage: node fix-model.js
 */

const fs = require('fs');

const OLD_MODEL = 'llama3-8b-8192';
const NEW_MODEL = 'llama-3.3-70b-versatile';   // current Groq flagship — best for creative/music tasks

const TARGETS = [
  'html/music-command/index.html',
  'test-assistant.js',
];

let anyFixed = false;

for (const file of TARGETS) {
  if (!fs.existsSync(file)) {
    console.log(`⏭   ${file} — not found, skipping`);
    continue;
  }

  const src = fs.readFileSync(file, 'utf8');
  const count = (src.split(OLD_MODEL)).length - 1;

  if (count === 0) {
    console.log(`⏭   ${file} — model already up to date`);
    continue;
  }

  // Backup
  const bak = file + '.bak.' + Date.now();
  fs.writeFileSync(bak, src);

  const updated = src.split(OLD_MODEL).join(NEW_MODEL);
  fs.writeFileSync(file, updated, 'utf8');
  console.log(`✅  ${file} — replaced ${count} occurrence(s)  →  ${NEW_MODEL}`);
  console.log(`    Backup: ${bak}`);
  anyFixed = true;
}

if (anyFixed) {
  console.log('\n🔁  Now re-run the tests:');
  console.log('    node test-assistant.js --verbose');
} else {
  console.log('\nNothing to change.');
}
