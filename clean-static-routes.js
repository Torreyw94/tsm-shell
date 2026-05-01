#!/usr/bin/env node
// clean-static-routes.js
// Removes all app.use('/html/...') static declarations EXCEPT hub, shared, suite

const fs = require('fs');
const target = process.argv[2] || './server.js';
const src = fs.readFileSync(target, 'utf8');

const KEEP = ['hub', 'shared', 'suite', 'suite-builder'];

const lines = src.split('\n');
const removed = [];
const kept = [];

const cleaned = lines.filter(line => {
  // Match lines like: app.use('/html/something', express.static(...))
  const match = line.match(/app\.use\(['"]\/html\/([^'"]+)['"]/);
  if (!match) return true; // not an html static line, keep it

  const name = match[1];
  const shouldKeep = KEEP.some(k => name === k || name.startsWith(k));

  if (shouldKeep) {
    kept.push(name);
    return true;
  } else {
    removed.push(name);
    return false;
  }
});

fs.writeFileSync(target + '.bak-static', src);
fs.writeFileSync(target, cleaned.join('\n'));

console.log(`✅ Removed ${removed.length} unused static routes:`);
removed.forEach(r => console.log('  -', r));
console.log(`\n✅ Kept ${kept.length} static routes:`);
kept.forEach(k => console.log('  +', k));
console.log('\nBackup saved ->', target + '.bak-static');
console.log('\nRun: node --check server.js && fly deploy');
