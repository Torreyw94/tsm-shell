#!/usr/bin/env node
// fix-route-v3.js — moves /api/finops/actions before app.use catch-all

const fs = require('fs');
const target = process.argv[2] || './server.js';
const src = fs.readFileSync(target, 'utf8');
const lines = src.split('\n');

// Find the catch-all line dynamically
const catchAllIdx = lines.findIndex(l => l.trim() === "app.use((req, res) => {");
if (catchAllIdx === -1) {
  console.error('Could not find app.use catch-all. Aborting.');
  process.exit(1);
}
console.log('Catch-all found at line', catchAllIdx + 1);

// Find the finops/actions route dynamically
const routeIdx = lines.findIndex(l => l.includes("app.get('/api/finops/actions'"));
if (routeIdx === -1) {
  console.error('Could not find /api/finops/actions route. Aborting.');
  process.exit(1);
}
console.log('Route found at line', routeIdx + 1);

if (routeIdx < catchAllIdx) {
  console.log('Route is already before catch-all. No changes needed.');
  process.exit(0);
}

// Extract the 4-line route block
const routeBlock = lines.splice(routeIdx, 4);
console.log('Extracted route block:');
routeBlock.forEach(l => console.log(' ', l));

// Re-find catch-all index after splice (it hasn't moved since route was after it)
const newCatchAllIdx = lines.findIndex(l => l.trim() === "app.use((req, res) => {");

// Insert route block + blank line before catch-all
lines.splice(newCatchAllIdx, 0, ...routeBlock, '');

fs.writeFileSync(target + '.bak4', src);
fs.writeFileSync(target, lines.join('\n'));

console.log('\nDone. Route moved before catch-all at line', newCatchAllIdx + 1);
console.log('Backup saved ->', target + '.bak4');
console.log('\nRun: node --check server.js && fly deploy');
