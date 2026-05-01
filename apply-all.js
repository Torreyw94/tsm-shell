#!/usr/bin/env node
// apply-all.js — rollback + dedup + syntax check + deploy

const fs = require('fs');
const { execSync } = require('child_process');

const target = './server.js';
const backup = './server.js.bak-dedup';

// ── 1. ROLLBACK ──────────────────────────────────────────────
if (!fs.existsSync(backup)) {
  console.error('❌ Backup not found:', backup);
  process.exit(1);
}
fs.writeFileSync(target, fs.readFileSync(backup));
console.log('✅ Rolled back to', backup);

// ── 2. DEDUP ─────────────────────────────────────────────────
const ROUTE_RE = /^app\.(get|post|put|delete|patch)\s*\(\s*['"]([^'"]+)['"]/;

let lines = fs.readFileSync(target, 'utf8').split('\n');
const seen = new Map();
const dupeStarts = new Set();

lines.forEach((line, i) => {
  const m = line.match(ROUTE_RE);
  if (!m) return;
  const key = `${m[1].toUpperCase()}:${m[2]}`;
  if (seen.has(key)) {
    console.log(`  DUPE removed: ${key} (line ${i + 1})`);
    dupeStarts.add(i);
  } else {
    seen.set(key, i);
  }
});

function findBlockEnd(idx) {
  const stripped = lines[idx].replace(/'[^']*'|"[^"]*"/g, '""');
  let depth = 0;
  for (const ch of stripped) {
    if (ch === '{' || ch === '(') depth++;
    if (ch === '}' || ch === ')') depth--;
  }
  if (depth <= 0) return idx; // single-line route

  let braceDepth = 0;
  for (let i = idx; i < lines.length; i++) {
    const s = lines[i].replace(/'[^']*'|"[^"]*"|`[^`]*`/g, '""');
    for (const ch of s) {
      if (ch === '{') braceDepth++;
      if (ch === '}') braceDepth--;
    }
    if (braceDepth <= 0 && i > idx) return i;
  }
  return idx;
}

const skipLines = new Set();
dupeStarts.forEach(idx => {
  const end = findBlockEnd(idx);
  for (let i = idx; i <= end; i++) skipLines.add(i);
});

const deduped = lines.filter((_, i) => !skipLines.has(i)).join('\n');
fs.writeFileSync(target + '.bak-clean', fs.readFileSync(target));
fs.writeFileSync(target, deduped);
console.log(`✅ Removed ${dupeStarts.size} duplicate blocks (${skipLines.size} lines)`);

// ── 3. SYNTAX CHECK ──────────────────────────────────────────
try {
  execSync('node --check server.js', { stdio: 'pipe' });
  console.log('✅ Syntax check passed');
} catch (e) {
  console.error('❌ Syntax error — rolling back:');
  console.error(e.stderr.toString());
  fs.writeFileSync(target, fs.readFileSync(backup));
  console.error('↩️  Restored original. No changes deployed.');
  process.exit(1);
}

// ── 4. DEPLOY ────────────────────────────────────────────────
console.log('\n🚀 Deploying...\n');
try {
  execSync('fly deploy', { stdio: 'inherit' });
} catch (e) {
  console.error('❌ Deploy failed.');
  process.exit(1);
}

// ── 5. VERIFY ────────────────────────────────────────────────
console.log('\n🔍 Verifying /api/finops/actions...');
try {
  const result = execSync('curl -s https://tsm-shell.fly.dev/api/finops/actions').toString();
  console.log('Response:', result);
  if (result.includes('"ok":true')) {
    console.log('\n✅ All done. Route is live and returning ok:true');
  } else {
    console.log('\n⚠️  Deployed but response unexpected. Check manually.');
  }
} catch(e) {
  console.log('⚠️  Could not verify endpoint. Check manually.');
}
