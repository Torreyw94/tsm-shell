#!/usr/bin/env node
// fix-route-order-v2.js — line-number precise, no regex mangling

const fs = require('fs');
const target = process.argv[2] || './server.js';

const src = fs.readFileSync(target, 'utf8');
const lines = src.split('\n');

// Validate key lines (1-indexed → 0-indexed)
const CATCH_ALL  = 3624 - 1;  // res.status(404)...
const ROUTE_START = 3666 - 1; // app.get('/api/finops/actions'...
const ROUTE_END   = 3669 - 1; // });

if (!lines[CATCH_ALL].includes('route not found')) {
  console.error('Line 3624 does not match catch-all. Aborting.');
  process.exit(1);
}
if (!lines[ROUTE_START].includes('/api/finops/actions')) {
  console.error('Line 3666 does not match route. Aborting.');
  process.exit(1);
}

// Extract the 4-line route block
const routeBlock = lines.slice(ROUTE_START, ROUTE_END + 1);
console.log('Route block to move:');
routeBlock.forEach(l => console.log(' ', l));

// Build new lines array:
// 1. Everything before the route block, minus the route lines
// 2. Insert route block just before the catch-all line
const before     = lines.slice(0, CATCH_ALL);       // up to (not including) catch-all
const catchOnward = lines.slice(CATCH_ALL);          // catch-all and everything after

// Remove the route block from catchOnward (it's after catch-all in the original)
// It's at original index ROUTE_START, which in catchOnward is ROUTE_START - CATCH_ALL
const routeOffsetInTail = ROUTE_START - CATCH_ALL;
catchOnward.splice(routeOffsetInTail, ROUTE_END - ROUTE_START + 1);

const result = [
  ...before,
  ...routeBlock,
  '',
  ...catchOnward
].join('\n');

// Backup + write
fs.writeFileSync(target + '.bak3', src);
fs.writeFileSync(target, result);

console.log('\n✅ Done. Route moved to before line 3624.');
console.log('✅ Backup saved →', target + '.bak3');
console.log('\nVerify then deploy:');
console.log('  node --check server.js && fly deploy');
