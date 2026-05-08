#!/usr/bin/env node
/**
 * TSM App Bug Fixer
 * Usage: node fix-tsm-apps.js <file1.html> <file2.html> ...
 * Example: node fix-tsm-apps.js auditops/index.html az-ins/index.html dme/index.html
 */

const fs = require('fs');

const PATCHES = [

  // ─── FIX 1: AuditOps Pro ─────────────────────────────────────────────────
  // Broken ternary inside template literal — crashes entire script block
  // 'aiTemp>0.7?aggressive' is a truthy string literal, not a condition
  {
    app: 'AuditOps Pro',
    find: `'aiTemp>0.7?aggressive'`,
    replace: `aiTemp>0.7?'aggressive'`,
    required: false,
  },

  // ─── FIX 2: AZ Insurance — sw() scope ────────────────────────────────────
  // sw() is defined inside DOMContentLoaded so inline onclick="sw(...)" can't reach it
  // Strategy: expose it on window right before DOMContentLoaded closes
  // Handles: function sw(...) and const/let sw = (...)=>
  {
    app: 'AZ Insurance (sw function declaration)',
    find: /function sw\s*\(([^)]*)\)\s*\{/,
    replace: (match) => {
      // Change to window.sw so inline handlers can reach it
      return `window.sw = function(${ match.match(/function sw\s*\(([^)]*)\)/)[1] }) {`;
    },
    required: false,
  },
  {
    app: 'AZ Insurance (sw arrow function)',
    find: /(?:const|let)\s+sw\s*=\s*(?:\(([^)]*)\)|([a-z_$][a-z0-9_$]*))\s*=>/i,
    replace: (match, args1, args2) => {
      const args = args1 !== undefined ? args1 : args2;
      return `window.sw = (${args}) =>`;
    },
    required: false,
  },

  // ─── FIX 3: DME / Any app — smart quote replacement ──────────────────────
  // Curly/smart quotes break JS parsing. Replace with straight quotes.
  {
    app: 'All apps (smart quotes)',
    find: /[\u2018\u2019]/g,   // ' '  →  '
    replace: "'",
    required: false,
  },
  {
    app: 'All apps (smart double quotes)',
    find: /[\u201C\u201D]/g,   // " "  →  "
    replace: '"',
    required: false,
  },

  // ─── FIX 4: Any app — showTab scope (same pattern as sw) ─────────────────
  {
    app: 'showTab scope fix',
    find: /function showTab\s*\(([^)]*)\)\s*\{/,
    replace: (match) => {
      return `window.showTab = function(${ match.match(/function showTab\s*\(([^)]*)\)/)[1] }) {`;
    },
    required: false,
  },

  // ─── FIX 5: P&C / Any app — callAI missing fetch wrapper ─────────────────
  // Function body starts with bare `method:'POST'` instead of `fetch(AI, {`
  // Caused by accidentally deleting the opening fetch line
  {
    app: 'callAI missing fetch wrapper',
    find: /async function callAI\s*\(([^)]*)\)\s*\{\s*\n(\s*)method\s*:/,
    replace: (match, args, indent) => {
      return `async function callAI(${args}) {\n${indent}const r = await fetch(AI, {\n${indent}  method:`;
    },
    required: false,
  },

  // ─── FIX 6: Any app — selectPreset / runAuditPreset scope ────────────────
  {
    app: 'selectPreset scope fix',
    find: /function selectPreset\s*\(([^)]*)\)\s*\{/,
    replace: (match) => {
      return `window.selectPreset = function(${ match.match(/function selectPreset\s*\(([^)]*)\)/)[1] }) {`;
    },
    required: false,
  },

  // ─── FIX 7: Any app — toggleDomain scope ─────────────────────────────────
  {
    app: 'toggleDomain scope fix',
    find: /function toggleDomain\s*\(([^)]*)\)\s*\{/,
    replace: (match) => {
      return `window.toggleDomain = function(${ match.match(/function toggleDomain\s*\(([^)]*)\)/)[1] }) {`;
    },
    required: false,
  },

];

function applyFix(content, patch) {
  if (typeof patch.find === 'string') {
    if (!content.includes(patch.find)) return { content, hit: false };
    return { content: content.split(patch.find).join(patch.replace), hit: true };
  }
  if (patch.find instanceof RegExp) {
    const hit = patch.find.test(content);
    if (!hit) return { content, hit: false };
    return {
      content: content.replace(patch.find, patch.replace),
      hit: true
    };
  }
  return { content, hit: false };
}

function fixFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`  ✗ File not found: ${filePath}`);
    return;
  }

  let content = fs.readFileSync(filePath, 'utf8');
  const original = content;
  const applied = [];

  for (const patch of PATCHES) {
    const { content: next, hit } = applyFix(content, patch);
    if (hit) {
      content = next;
      applied.push(patch.app);
    }
  }

  if (content === original) {
    console.log(`  ○ No changes needed: ${filePath}`);
    return;
  }

  // Backup original
  const backup = filePath + '.bak';
  fs.writeFileSync(backup, original, 'utf8');
  fs.writeFileSync(filePath, content, 'utf8');

  console.log(`  ✓ Fixed: ${filePath}`);
  console.log(`    Backup: ${backup}`);
  applied.forEach(a => console.log(`    └─ Applied: ${a}`));
}

// ─── Main ────────────────────────────────────────────────────────────────────
const files = process.argv.slice(2);
if (!files.length) {
  console.log('Usage: node fix-tsm-apps.js <file1.html> [file2.html] ...');
  console.log('Example: node fix-tsm-apps.js auditops/index.html az-ins/index.html dme/index.html');
  process.exit(1);
}

console.log('\nTSM App Bug Fixer\n' + '─'.repeat(40));
files.forEach(f => {
  console.log(`\nProcessing: ${f}`);
  fixFile(f);
});
console.log('\n' + '─'.repeat(40));
console.log('Done. Review changes then redeploy.\n');

// ─── Dockerfile check ────────────────────────────────────────────────────────
const dockerfiles = ['./Dockerfile', './fly.toml', './.fly/Dockerfile'];
console.log('\n─── Dockerfile Check ───────────────────────────────────');
for (const df of dockerfiles) {
  if (!fs.existsSync(df)) continue;
  const dfc = fs.readFileSync(df, 'utf8');
  if (/<html|<body|<head/i.test(dfc)) {
    console.error(`  ✗ HTML leaked into ${df} — this breaks fly deploy. Remove those lines.`);
  } else {
    console.log(`  ✓ ${df} is clean`);
  }
}
