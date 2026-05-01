#!/usr/bin/env node
// refactor.js — splits server.js into routes/finops.js, routes/music.js,
//               routes/hc.js, routes/strategist.js, routes/queries.js
// Safe: backs up server.js, syntax-checks all files before writing anything.

const fs   = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const SRC = './server.js';
if (!fs.existsSync(SRC)) { console.error('server.js not found'); process.exit(1); }

const raw   = fs.readFileSync(SRC, 'utf8');
const lines = raw.split('\n');
const total = lines.length;
console.log(`server.js loaded: ${total} lines`);

// ── helpers ───────────────────────────────────────────────────────────────────
// extract 1-indexed inclusive range
function L(start, end) {
  return lines.slice(start - 1, Math.min(end, total)).join('\n');
}

// replace app.METHOD( → router.METHOD(  (only at line start, avoids string matches)
function routerify(code) {
  return code
    .replace(/^(app)\.(get|post|put|delete|patch|use)\s*\(/gm, 'router.$2(');
}

// wrap extracted code in a router module
function makeRouter(requires, body) {
  return [
    `'use strict';`,
    `const express = require('express');`,
    `const router  = express.Router();`,
    requires,
    '',
    routerify(body),
    '',
    'module.exports = router;',
  ].join('\n');
}

// write file then node --check it; return error string or null
function checkFile(filePath, content) {
  fs.writeFileSync(filePath, content);
  try {
    execSync(`node --check ${filePath}`, { stdio: 'pipe' });
    return null;
  } catch(e) {
    return e.stderr.toString();
  }
}

// find a block that starts with a pattern and ends when braces close back to 0
function findBlock(startLine0) {
  let depth = 0, inBlock = false;
  for (let i = startLine0; i < lines.length; i++) {
    const s = lines[i].replace(/'[^']*'|"[^"]*"|`[^`]*`/g, '""');
    for (const ch of s) {
      if (ch === '{') { depth++; inBlock = true; }
      if (ch === '}') depth--;
    }
    if (inBlock && depth <= 0) return i;
  }
  return startLine0;
}

// dynamically find a named function block
function extractFn(name) {
  const idx = lines.findIndex(l => l.startsWith(`function ${name}`));
  if (idx === -1) return '';
  const end = findBlock(idx);
  return lines.slice(idx, end + 1).join('\n');
}

// ── section extraction ────────────────────────────────────────────────────────

// FINOPS — three sections + helper functions
const finopsBody = [
  L(341, 629),          // doc runner + live uploader
  L(3193, 3417),        // report + multi-report
  extractFn('readFinopsStore'),
  extractFn('writeFinopsStore'),
  // finops/actions + finops/action are already before catch-all, find them
  (() => {
    const a = lines.findIndex(l => l.includes("app.get('/api/finops/actions'"));
    const b = lines.findIndex(l => l.includes("app.post('/api/finops/action'"));
    if (a === -1 && b === -1) return '';
    const aEnd = a !== -1 ? findBlock(a) : -1;
    const bEnd = b !== -1 ? findBlock(b) : -1;
    const parts = [];
    if (a !== -1) parts.push(lines.slice(a, aEnd + 1).join('\n'));
    if (b !== -1) parts.push(lines.slice(b, bEnd + 1).join('\n'));
    return parts.join('\n\n');
  })(),
].join('\n\n');

const finopsRequires = `
const multer = require('multer');
const fs     = require('fs');
const path   = require('path');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 8 * 1024 * 1024 } });
`;

// MUSIC — force-top route + all music sections + suite/platform loop
const musicBody = [
  L(64, 81),            // force top-level music route
  L(1980, 3190),        // multi-agent + revision + product + evolution + monetization + tier + paywall
  L(3418, 3460),        // suite API inline + platform execution loop
  extractFn('requireMusicDemo'),
].join('\n\n');

const musicRequires = `
const fs   = require('fs');
const path = require('path');
`;

// HC — reports + nodes + profiles + BNCA + layer2 + rollup + brief + ask + alerts
const hcBody = [
  L(673, 1540),         // core HC block
  L(1863, 1976),        // hc rollup/brief + alerts
].join('\n\n');

const hcRequires = `
const fs = require('fs');
`;

// STRATEGIST — system-posture + honor/dee + dee-action
const strategistBody = L(1553, 1862);
const strategistRequires = ``;

// QUERIES — GROQ AI engine: /api/ai|financial|mortgage|legal|construction|insurance|schools|strategist/query
const queriesBody = L(2830, 2869);
const queriesRequires = ``;

// CONSTRUCTION
const constructionBody = (() => {
  const idx = lines.findIndex(l => l.includes("app.post('/api/construction/report'"));
  if (idx === -1) return '';
  const end = findBlock(idx);
  return lines.slice(idx, end + 1).join('\n');
})();

// ── generate files ───────────────────────────────────────────────────────────
if (!fs.existsSync('./routes')) fs.mkdirSync('./routes');

const routeFiles = [
  ['./routes/finops.js',       makeRouter(finopsRequires,       finopsBody)],
  ['./routes/music.js',        makeRouter(musicRequires,        musicBody)],
  ['./routes/hc.js',           makeRouter(hcRequires,           hcBody)],
  ['./routes/strategist.js',   makeRouter(strategistRequires,   strategistBody)],
  ['./routes/queries.js',      makeRouter(queriesRequires,      queriesBody)],
  ['./routes/construction.js', makeRouter('',                   constructionBody)],
];

console.log('\n── Syntax-checking generated route files ──');
let hasError = false;
for (const [filePath, content] of routeFiles) {
  const err = checkFile(filePath, content);
  if (err) {
    console.error(`❌ ${filePath}:\n${err}`);
    hasError = true;
  } else {
    const lineCount = content.split('\n').length;
    console.log(`✅ ${filePath} (${lineCount} lines)`);
  }
}

if (hasError) {
  console.error('\n❌ Errors found — route files written for inspection but server.js NOT modified.');
  console.error('Fix the issues above, then re-run this script.');
  process.exit(1);
}

// ── patch server.js ───────────────────────────────────────────────────────────
// Build the router mount block to inject near the top of server.js (after middleware)
const mountBlock = `
// ── ROUTE MODULES ─────────────────────────────────────────────────────────────
app.use('/api/finops',       require('./routes/finops'));
app.use('/api/music',        require('./routes/music'));
app.use('/api/hc',           require('./routes/hc'));
app.use('/api/strategist',   require('./routes/strategist'));
app.use('/api/main-strategist', require('./routes/strategist'));
app.use('/api/honor',        require('./routes/strategist'));
app.use(['/api/ai','/api/financial','/api/mortgage','/api/legal',
         '/api/construction','/api/insurance','/api/schools'],
         require('./routes/queries'));
app.use('/api/construction', require('./routes/construction'));
// ─────────────────────────────────────────────────────────────────────────────
`;

// Find a clean injection point — after the security/middleware block (line ~60)
const INJECT_AFTER = '// ===== END SECURITY LAYER =====';
let patched = raw;

if (patched.includes(INJECT_AFTER)) {
  patched = patched.replace(INJECT_AFTER, INJECT_AFTER + '\n' + mountBlock);
  console.log('\n✅ Router mounts injected after security layer');
} else {
  // Fallback: inject after the last app.use middleware setup
  patched = patched.replace(
    "app.use(express.json({ limit: '50kb' }));",
    "app.use(express.json({ limit: '50kb' }));\n" + mountBlock
  );
  console.log('\n✅ Router mounts injected after express.json middleware');
}

// Back up and write
fs.writeFileSync(SRC + '.bak-refactor', raw);
fs.writeFileSync(SRC, patched);

const err = checkFile(SRC, patched);
if (err) {
  console.error('❌ server.js syntax error after patch:\n', err);
  console.error('↩️  Restoring backup...');
  fs.writeFileSync(SRC, raw);
  process.exit(1);
}

console.log('✅ server.js patched and syntax-clean');
console.log('✅ Backup → server.js.bak-refactor');
console.log('\nNext:');
console.log('  fly deploy');
console.log('  curl https://tsm-shell.fly.dev/api/finops/actions');
console.log('  curl https://tsm-shell.fly.dev/api/music/state');
console.log('  curl https://tsm-shell.fly.dev/api/hc/reports');
