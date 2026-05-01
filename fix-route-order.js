#!/usr/bin/env node
// fix-route-order.js
// Moves /api/finops/actions before the 404 catch-all in server.js

const fs = require('fs');
const path = require('path');

const target = process.argv[2] || path.join(__dirname, 'server.js');

if (!fs.existsSync(target)) {
  console.error('❌ File not found:', target);
  process.exit(1);
}

let src = fs.readFileSync(target, 'utf8');

// 1. Verify catch-all exists
if (!src.includes("error: 'API route not found'")) {
  console.error("❌ Could not find catch-all 404 handler. Aborting.");
  process.exit(1);
}

// 2. Remove the existing /api/finops/actions GET block (wherever it is)
const routeRegex = /app\.get\('\/api\/finops\/actions'[\s\S]*?\}\);\n?/;
const match = src.match(routeRegex);

if (!match) {
  console.error("❌ Could not find the /api/finops/actions route block. Aborting.");
  process.exit(1);
}

const routeBlock = match[0].trim();
console.log("✅ Found route block to move.");

// Remove it from its current position
src = src.replace(routeRegex, '');

// 3. Insert it just before the 404 catch-all line
const catchAllMarker = "res.status(404).json({ ok: false, error: 'API route not found' })";
src = src.replace(catchAllMarker, routeBlock + '\n\n' + catchAllMarker);

// 4. Write backup + save
fs.writeFileSync(target + '.bak2', fs.readFileSync(target));
fs.writeFileSync(target, src);

console.log('✅ Route moved before catch-all handler.');
console.log('✅ Backup saved →', target + '.bak2');
console.log('');
console.log('Next steps:');
console.log('  fly deploy');
console.log('  curl https://tsm-shell.fly.dev/api/finops/actions');
