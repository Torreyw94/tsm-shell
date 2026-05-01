#!/usr/bin/env node
// dedup-routes.js
// Finds duplicate Express route definitions and removes later ones
// Keeps the FIRST occurrence of each (method + path) combo

const fs = require('fs');
const target = process.argv[2] || './server.js';
const src = fs.readFileSync(target, 'utf8');
const lines = src.split('\n');

// Match route definition lines
const ROUTE_RE = /^app\.(get|post|put|delete|patch)\s*\(\s*['"]([^'"]+)['"]/;

const seen = new Map(); // "METHOD:path" -> first line number
const dupeStarts = new Set(); // line indexes to start skipping

lines.forEach((line, i) => {
  const m = line.match(ROUTE_RE);
  if (!m) return;
  const key = `${m[1].toUpperCase()}:${m[2]}`;
  if (seen.has(key)) {
    console.log(`DUPE found: ${key} at line ${i + 1} (first seen at line ${seen.get(key) + 1})`);
    dupeStarts.add(i);
  } else {
    seen.set(key, i);
  }
});

if (dupeStarts.size === 0) {
  console.log('No duplicate routes found. Nothing to do.');
  process.exit(0);
}

// Now rebuild file, skipping duplicate route blocks
// A block ends when we find the matching closing `});` at the same indent level
const result = [];
let skipDepth = 0;
let skipping = false;
let removedLines = 0;

lines.forEach((line, i) => {
  if (dupeStarts.has(i)) {
    skipping = true;
    skipDepth = 0;
    removedLines++;
    return;
  }

  if (skipping) {
    removedLines++;
    // Count braces to find end of block
    for (const ch of line) {
      if (ch === '{') skipDepth++;
      if (ch === '}') skipDepth--;
    }
    // Block ends when we close back to 0 and hit the `});` pattern
    if (skipDepth <= 0 && line.trim().match(/^\}\s*\)?\s*;?\s*$/)) {
      skipping = false;
    }
    return;
  }

  result.push(line);
});

fs.writeFileSync(target + '.bak-dedup', src);
fs.writeFileSync(target, result.join('\n'));

console.log(`\n✅ Removed ${dupeStarts.size} duplicate route blocks (~${removedLines} lines)`);
console.log(`✅ Backup saved → ${target}.bak-dedup`);
console.log('\nRun: node --check server.js && fly deploy');
