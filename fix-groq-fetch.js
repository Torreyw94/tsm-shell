#!/usr/bin/env node
/**
 * fix-groq-fetch.js
 * Restores the stripped fetch() calls in server.js
 * Run: node fix-groq-fetch.js
 */

const fs = require('fs');
const path = require('path');

const serverPath = path.join(process.cwd(), 'server.js');
let src = fs.readFileSync(serverPath, 'utf8');

// Back up first
fs.writeFileSync(serverPath + '.bak.' + Date.now(), src);
console.log('✅ Backup created');

const GROQ_FETCH = `await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + process.env.GROQ_API_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', messages: [{ role: 'user', content: prompt }], max_tokens: maxTokens, temperature: 0.7 })
  })`;

// ── 1. Fix musicAI() — broken pattern:
//   // ⚠️ removed invalid top-level await fetch
//   if(!r.ok) throw new Error("AI unavailable");
//   const data = await r.json();
src = src.replace(
  /\/\/ ⚠️ removed invalid top-level await fetch\s*\nif\(!r\.ok\) throw new Error\("AI unavailable"\);\s*\n\s*const data = await r\.json\(\);/g,
  `const r = ${GROQ_FETCH};\n    if(!r.ok) throw new Error("AI unavailable");\n    const data = await r.json();`
);

// ── 2. Fix groqFetch() — broken pattern:
//   // ⚠️ removed invalid top-level await fetch
//   const raw = await r.json();
//   if (raw.error?.code === 'rate_limit_exceeded') {
src = src.replace(
  /\/\/ ⚠️ removed invalid top-level await fetch\s*\nconst raw = await r\.json\(\);\s*\n\s*if \(raw\.error\?\.code === 'rate_limit_exceeded'\)/g,
  `const r = ${GROQ_FETCH};\n  const raw = await r.json();\n  if (raw.error?.code === 'rate_limit_exceeded')`
);

// ── 3. Fix inline route handlers — broken pattern:
//   try { // ⚠️ removed invalid top-level await fetch
//   const raw = await r.json(); const text = ...
src = src.replace(
  /try \{ \/\/ ⚠️ removed invalid top-level await fetch\s*\nconst raw = await r\.json\(\); const text = \(raw\.choices\?\.\[0\]\?\.message\?\.content \|\| ''\)\.replace\(\/```json\|```\/g,''\)\.trim\(\); return res\.json\(safeParseGroq\(text, \{ok:false\}\)\); \}/g,
  `try {
    const r = ${GROQ_FETCH};
    const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/\`\`\`json|\`\`\`/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); }`
);

// ── 4. Fix /api/music/llm route — broken pattern:
//   // ⚠️ removed invalid top-level await fetch
//   const d = await r.json();
src = src.replace(
  /\/\/ ⚠️ removed invalid top-level await fetch\s*\nconst d = await r\.json\(\);/g,
  `const _llmPrompt = (system ? system + '\\n\\n' : '') + user;
    const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + process.env.GROQ_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', messages: [{ role: 'user', content: _llmPrompt }], max_tokens: 1000, temperature: 0.7 })
    });
    const d = await r.json();`
);

fs.writeFileSync(serverPath, src);
console.log('✅ server.js patched');

// Verify no broken patterns remain
const remaining = (src.match(/removed invalid top-level await fetch/g) || []).length;
if (remaining === 0) {
  console.log('✅ All broken fetch patterns fixed!');
} else {
  console.log(`⚠️  ${remaining} broken pattern(s) still remain — may need manual review`);
  // Show line numbers of remaining issues
  src.split('\n').forEach((line, i) => {
    if (line.includes('removed invalid top-level await fetch')) {
      console.log(`   Line ${i+1}: ${line.trim()}`);
    }
  });
}
