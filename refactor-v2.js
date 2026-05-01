#!/usr/bin/env node
// refactor-v2.js — dynamic section detection, immune to line-number shifts

const fs   = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const SRC = './server.js';
const raw   = fs.readFileSync(SRC, 'utf8');
const lines = raw.split('\n');
console.log(`server.js: ${lines.length} lines`);

// ── core helpers ──────────────────────────────────────────────────────────────

// Find the closing line of a block starting at startIdx (0-indexed)
function findBlockEnd(startIdx) {
  const stripped = lines[startIdx].replace(/'[^']*'|"[^"]*"|`[^`]*`/g, '""');
  let depth = 0, opened = false;
  for (const ch of stripped) {
    if (ch === '{') { depth++; opened = true; }
    if (ch === '}') depth--;
  }
  if (opened && depth <= 0) return startIdx; // single-line

  let braceDepth = 0;
  for (let i = startIdx; i < lines.length; i++) {
    const s = lines[i].replace(/'[^']*'|"[^"]*"|`[^`]*`/g, '""');
    for (const ch of s) {
      if (ch === '{') braceDepth++;
      if (ch === '}') braceDepth--;
    }
    if (braceDepth <= 0 && i > startIdx) return i;
  }
  return startIdx;
}

// Extract all route blocks matching a URL prefix pattern
function extractRouteBlocks(prefixPattern) {
  const RE = new RegExp(`^app\\.(get|post|put|delete|patch)\\s*\\(['"]${prefixPattern}`);
  const blocks = [];
  lines.forEach((line, i) => {
    if (RE.test(line)) {
      const end = findBlockEnd(i);
      blocks.push(lines.slice(i, end + 1).join('\n'));
    }
  });
  return blocks.join('\n\n');
}

// Extract a named function (function name(...) { ... })
function extractFn(name) {
  const idx = lines.findIndex(l => new RegExp(`^function\\s+${name}\\b`).test(l));
  if (idx === -1) { console.warn(`  WARNING: function ${name} not found`); return ''; }
  const end = findBlockEnd(idx);
  return lines.slice(idx, end + 1).join('\n');
}

// Extract a section between two comment markers
function extractBetween(startMarker, endMarker) {
  const startIdx = lines.findIndex(l => l.includes(startMarker));
  if (startIdx === -1) { console.warn(`  WARNING: marker not found: "${startMarker}"`); return ''; }
  let endIdx = lines.length - 1;
  if (endMarker) {
    const found = lines.findIndex((l, i) => i > startIdx && l.includes(endMarker));
    if (found !== -1) endIdx = found;
  }
  return lines.slice(startIdx, endIdx + 1).join('\n');
}

// Replace app.METHOD( → router.METHOD( at line start
function routerify(code) {
  return code.replace(/^app\.(get|post|put|delete|patch|use)\s*\(/gm, 'router.$1(');
}

// Build a router module file
function makeRouter(header, body) {
  return [
    `'use strict';`,
    `const express = require('express');`,
    `const router  = express.Router();`,
    header,
    '',
    routerify(body),
    '',
    'module.exports = router;',
  ].filter(s => s !== undefined).join('\n');
}

// Syntax-check a file; return error string or null
function syntaxCheck(filePath) {
  try { execSync(`node --check ${filePath}`, { stdio: 'pipe' }); return null; }
  catch(e) { return e.stderr.toString().trim(); }
}

if (!fs.existsSync('./routes')) fs.mkdirSync('./routes');

// ── FINOPS ────────────────────────────────────────────────────────────────────
console.log('\nBuilding routes/finops.js...');
const finopsBody = [
  // multer setup is already in the extracted range — don't re-declare it
  extractBetween('FINOPS DOCUMENT RUNNER', 'FINOPS STATIC ROUTE LOCK'),
  extractBetween('FINOPS LIVE UPLOADER', 'FINOPS STATIC ROUTE LOCK'),
  extractRouteBlocks('/api/finops/'),
  extractFn('readFinopsStore'),
  extractFn('writeFinopsStore'),
].join('\n\n');

const finopsHeader = `
const fs   = require('fs');
const path = require('path');
`;

// ── MUSIC ─────────────────────────────────────────────────────────────────────
console.log('Building routes/music.js...');
const musicBody = [
  extractBetween('FORCE MUSIC ROUTE (TOP LEVEL)', 'END MUSIC ROUTE'),
  extractBetween('MUSIC MULTI-AGENT ENGINE', 'END MUSIC MULTI-AGENT ENGINE'),
  extractBetween('MUSIC REVISION MODE', 'END MUSIC REVISION MODE'),
  extractBetween('MUSIC PRODUCT LAYER', 'END MUSIC PRODUCT LAYER'),
  extractBetween('MUSIC EVOLUTION TIMELINE', 'END MUSIC EVOLUTION TIMELINE'),
  extractBetween('MUSIC MONETIZATION', 'END MUSIC MONETIZATION'),
  extractBetween('MUSIC TIER', 'END MUSIC TIER'),
  extractBetween('MUSIC PROTECTION LAYER', 'END MUSIC PROTECTION LAYER'),
  extractBetween('MUSIC DEMO DEAL-CLOSING MODE', 'END MUSIC DEMO DEAL-CLOSING MODE'),
  extractBetween('MUSIC REVISION RUN COMPATIBILITY ROUTE', 'END MUSIC REVISION RUN COMPATIBILITY ROUTE'),
  extractBetween('MUSIC SUITE API INLINE', 'END MUSIC SUITE API INLINE'),
  extractBetween('MUSIC PLATFORM EXECUTION LOOP', 'END MUSIC PLATFORM EXECUTION LOOP'),
  extractFn('requireMusicDemo'),
].join('\n\n');

const musicHeader = `
const fs   = require('fs');
const path = require('path');
`;

// ── HC ────────────────────────────────────────────────────────────────────────
console.log('Building routes/hc.js...');
const hcBody = extractRouteBlocks('/api/hc/');
const hcHeader = `const fs = require('fs');`;

// ── STRATEGIST ────────────────────────────────────────────────────────────────
console.log('Building routes/strategist.js...');
const strategistBody = [
  extractRouteBlocks('/api/strategist/'),
  extractRouteBlocks('/api/main-strategist/'),
  extractRouteBlocks('/api/honor/'),
].join('\n\n');

// ── QUERIES (GROQ AI ENGINE) ──────────────────────────────────────────────────
console.log('Building routes/queries.js...');
// Include the full GROQ engine section (helper + routes)
const queriesBody = extractBetween('GROQ AI ENGINE', 'END GROQ AI ENGINE');
const queriesHeader = ``;

// ── CONSTRUCTION ──────────────────────────────────────────────────────────────
console.log('Building routes/construction.js...');
const constructionBody = extractRouteBlocks('/api/construction/');

// ── generate + check ──────────────────────────────────────────────────────────
const routeFiles = [
  ['./routes/finops.js',        makeRouter(finopsHeader,    finopsBody)],
  ['./routes/music.js',         makeRouter(musicHeader,     musicBody)],
  ['./routes/hc.js',            makeRouter(hcHeader,        hcBody)],
  ['./routes/strategist.js',    makeRouter('',              strategistBody)],
  ['./routes/queries.js',       makeRouter(queriesHeader,   queriesBody)],
  ['./routes/construction.js',  makeRouter('',              constructionBody)],
];

console.log('\n── Syntax checking ───────────────────────────────────────────────');
let hasError = false;
for (const [filePath, content] of routeFiles) {
  fs.writeFileSync(filePath, content);
  const err = syntaxCheck(filePath);
  if (err) {
    console.error(`❌ ${filePath}:\n   ${err.split('\n').slice(0,3).join('\n   ')}`);
    hasError = true;
  } else {
    console.log(`✅ ${filePath} (${content.split('\n').length} lines)`);
  }
}

if (hasError) {
  console.error('\n❌ Fix errors above — server.js NOT modified.');
  process.exit(1);
}

// ── patch server.js ───────────────────────────────────────────────────────────
const mountBlock = `
// ── ROUTE MODULES ─────────────────────────────────────────────────────────────
app.use('/api/finops',            require('./routes/finops'));
app.use('/api/music',             require('./routes/music'));
app.use('/api/hc',                require('./routes/hc'));
app.use('/api/strategist',        require('./routes/strategist'));
app.use('/api/main-strategist',   require('./routes/strategist'));
app.use('/api/honor',             require('./routes/strategist'));
app.use('/api/ai',                require('./routes/queries'));
app.use('/api/financial',         require('./routes/queries'));
app.use('/api/mortgage',          require('./routes/queries'));
app.use('/api/legal',             require('./routes/queries'));
app.use('/api/insurance',         require('./routes/queries'));
app.use('/api/schools',           require('./routes/queries'));
app.use('/api/construction',      require('./routes/construction'));
// ─────────────────────────────────────────────────────────────────────────────
`;

const INJECT_ANCHOR = '// ===== END SECURITY LAYER =====';
let patched = raw;

if (raw.includes(INJECT_ANCHOR)) {
  patched = raw.replace(INJECT_ANCHOR, INJECT_ANCHOR + '\n' + mountBlock);
  console.log('\n✅ Router mounts injected after security layer');
} else {
  patched = raw.replace(
    "app.use(express.json({ limit: '50kb' }));",
    "app.use(express.json({ limit: '50kb' }));\n" + mountBlock
  );
  console.log('\n✅ Router mounts injected after express.json middleware');
}

fs.writeFileSync(SRC + '.bak-refactor', raw);
fs.writeFileSync(SRC, patched);

const serverErr = syntaxCheck(SRC);
if (serverErr) {
  console.error('❌ server.js syntax error:\n', serverErr);
  fs.writeFileSync(SRC, raw);
  console.error('↩️  Restored original.');
  process.exit(1);
}

console.log('✅ server.js patched and syntax-clean');
console.log('✅ Backup → server.js.bak-refactor');
console.log('\nDeploy: fly deploy');
console.log('Verify:');
console.log('  curl https://tsm-shell.fly.dev/api/finops/actions');
console.log('  curl https://tsm-shell.fly.dev/api/music/state');
console.log('  curl https://tsm-shell.fly.dev/api/hc/reports');
