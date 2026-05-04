#!/usr/bin/env node
'use strict';

/**
 * fix-duplicate-and-key.js
 * 1. Removes the original tsmStudioGuide() — keeps only the tab-aware override
 * 2. Fixes the Groq key regex in test-assistant.js to catch all key formats
 *
 * Usage: node fix-duplicate-and-key.js
 */

const fs = require('fs');

// ─── Fix 1: Remove original tsmStudioGuide() from HTML ───────────────────────

const HTML_FILE = 'html/music-command/index.html';

if (!fs.existsSync(HTML_FILE)) {
  console.error(`❌  ${HTML_FILE} not found`); process.exit(1);
}

let html = fs.readFileSync(HTML_FILE, 'utf8');
fs.writeFileSync(HTML_FILE + '.bak.' + Date.now(), html);

// Find ALL occurrences of function tsmStudioGuide
const FN_SIG = 'function tsmStudioGuide()';
const positions = [];
let pos = 0;
while ((pos = html.indexOf(FN_SIG, pos)) !== -1) {
  positions.push(pos);
  pos += FN_SIG.length;
}

console.log(`\n── Fix 1: tsmStudioGuide duplicates ─────────────────────────────`);
console.log(`   Found ${positions.length} definition(s) at positions: ${positions.join(', ')}`);

if (positions.length < 2) {
  console.log('⏭   Only one definition found — nothing to remove');
} else {
  // Keep the LAST definition (the tab-aware override added by patch-contextual-coaching)
  // Remove all earlier ones by extracting each function body and deleting it

  // We'll remove definitions in reverse order so positions stay valid
  // Work from last-to-first among the ones to DELETE (all except the last)
  const toRemove = positions.slice(0, -1); // keep last, remove all earlier

  for (let i = toRemove.length - 1; i >= 0; i--) {
    const start = toRemove[i];

    // Find the opening brace of this function
    const braceOpen = html.indexOf('{', start);
    if (braceOpen === -1) { console.warn(`⚠️   Could not find opening brace at pos ${start}`); continue; }

    // Walk forward matching braces to find the closing brace
    let depth = 0;
    let end = braceOpen;
    for (let j = braceOpen; j < html.length; j++) {
      if (html[j] === '{') depth++;
      else if (html[j] === '}') {
        depth--;
        if (depth === 0) { end = j; break; }
      }
    }

    // Also eat any trailing newlines
    while (end + 1 < html.length && (html[end + 1] === '\n' || html[end + 1] === '\r')) end++;

    const removed = html.slice(start, end + 1);
    console.log(`✅  Removed original tsmStudioGuide() (${removed.length} chars)`);
    console.log(`   Preview: ${removed.slice(0, 80).replace(/\n/g,' ')}...`);

    html = html.slice(0, start) + html.slice(end + 1);
  }

  // Verify
  const remaining = (html.split(FN_SIG)).length - 1;
  if (remaining === 1) console.log(`✅  tsmStudioGuide() now defined exactly once`);
  else console.warn(`⚠️   Still ${remaining} definitions — check manually`);

  fs.writeFileSync(HTML_FILE, html, 'utf8');
  console.log(`✅  HTML written`);
}

// ─── Fix 2: Broaden Groq key detection in test-assistant.js ──────────────────

console.log(`\n── Fix 2: Groq key extraction regex ─────────────────────────────`);

const TEST_FILE = 'test-assistant.js';
if (!fs.existsSync(TEST_FILE)) {
  console.warn(`⚠️   ${TEST_FILE} not found — skipping`);
} else {
  let src = fs.readFileSync(TEST_FILE, 'utf8');
  fs.writeFileSync(TEST_FILE + '.bak.' + Date.now(), src);

  // Replace narrow regex with one that catches key in JS variables, env assignments, fetch headers
  const OLD_REGEX = `const keyMatch      = html.match(/['"\`](gsk_[A-Za-z0-9]{20,})['"\`]/);`;
  const NEW_REGEX  = `// Broader key search: catches gsk_ keys in any quote style, header assignments, or env vars
  const keyMatch = html.match(/gsk_[A-Za-z0-9_]{20,}/)
                || html.match(/['"\`](gsk_[A-Za-z0-9_]{20,})['"\`]/)
                || html.match(/GROQ_API_KEY[^'"\`]*['"\`]([^'"\`]{20,})['"\`]/);`;

  if (src.includes(OLD_REGEX)) {
    src = src.replace(OLD_REGEX, NEW_REGEX);
    // Also fix how the key is extracted from the match (index 0 vs 1)
    const OLD_KEY_EXTRACT = `let groqKey      = keyMatch      ? keyMatch[1]      : null;`;
    const NEW_KEY_EXTRACT  = `let groqKey = keyMatch
    ? (keyMatch[1] || keyMatch[0])  // broader regex may not have a capture group
    : null;`;
    if (src.includes(OLD_KEY_EXTRACT)) {
      src = src.replace(OLD_KEY_EXTRACT, NEW_KEY_EXTRACT);
      console.log('✅  Key extraction updated — now catches gsk_ in any context');
    } else {
      console.log('✅  Regex updated (key extract line may differ — verify manually)');
    }
    fs.writeFileSync(TEST_FILE, src, 'utf8');
  } else {
    console.log('⏭   Regex anchor not found — checking if already fixed...');
    if (src.includes('Broader key search')) {
      console.log('⏭   Already using broad regex');
    } else {
      // Fallback: just add an env-var check at the top of the key section
      const envFallback = `\n  // Fallback: scan raw HTML for any gsk_ token\n  if (!groqKey) {\n    const rawMatch = html.match(/gsk_[A-Za-z0-9_]{20,}/);\n    if (rawMatch) groqKey = rawMatch[0];\n  }\n`;
      const insertAfter = `groqKey = process.env.GROQ_API_KEY || process.env.VITE_GROQ_API_KEY || null;`;
      if (src.includes(insertAfter)) {
        src = src.replace(insertAfter, insertAfter + envFallback);
        fs.writeFileSync(TEST_FILE, src, 'utf8');
        console.log('✅  Raw gsk_ fallback scanner added');
      }
    }
  }
}

// ─── Summary ─────────────────────────────────────────────────────────────────

console.log(`\n─────────────────────────────────────────────────────────────────`);
console.log(`🔁  Re-run tests:`);
console.log(`    node test-assistant.js --verbose`);
console.log(`\n🚀  If all green:`);
console.log(`    fly deploy -a tsm-shell`);
