#!/usr/bin/env node
/**
 * fix-all-groq.js
 * Fixes ALL broken fetch patterns in server.js by:
 * 1. Fixing musicAI() core function
 * 2. Replacing all inline broken r/d/raw patterns with groqFetch() calls
 */

const fs = require('fs');
const src_path = 'server.js';
let s = fs.readFileSync(src_path, 'utf8');

// Backup
const bak = src_path + '.bak.fix-all.' + Date.now();
fs.writeFileSync(bak, s);
console.log('✅ Backup:', bak);

const GROQ_FETCH_INLINE = `await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + process.env.GROQ_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', messages: [{ role: 'user', content: prompt }], max_tokens: 900, temperature: 0.7 })
    })`;

// ── FIX 1: musicAI() core function ──────────────────────────────────────────
// Pattern:
//   if(!process.env.GROQ_API_KEY) throw new Error("missing key");
//   // ⚠️ removed invalid top-level await fetch
//   if(!r.ok) throw new Error("AI unavailable");
//   const data = await r.json();
s = s.replace(
  /if\(!process\.env\.GROQ_API_KEY\) throw new Error\("missing key"\);\s*\n\s*\/\/ ⚠️ removed invalid top-level await fetch\s*\nif\(!r\.ok\) throw new Error\("AI unavailable"\);\s*\n\s*const data = await r\.json\(\);/g,
  `if(!process.env.GROQ_API_KEY) throw new Error("missing key");
    const r = ${GROQ_FETCH_INLINE};
    if(!r.ok) throw new Error("AI unavailable");
    const data = await r.json();`
);

// ── FIX 2: groqFetch() function ─────────────────────────────────────────────
// Pattern:
//   // ⚠️ removed invalid top-level await fetch
//   const raw = await r.json();
//   if (raw.error?.code === 'rate_limit_exceeded') {
s = s.replace(
  /\/\/ ⚠️ removed invalid top-level await fetch\s*\nconst raw = await r\.json\(\);\s*\n\s*if \(raw\.error\?\.code === 'rate_limit_exceeded'\)/g,
  `const r = ${GROQ_FETCH_INLINE};
  const raw = await r.json();
  if (raw.error?.code === 'rate_limit_exceeded')`
);

// ── FIX 3: /api/music/llm route ─────────────────────────────────────────────
// Pattern:
//   // ⚠️ removed invalid top-level await fetch
//   const d = await r.json();
//   const text = d.choices?.[0]...
s = s.replace(
  /\/\/ ⚠️ removed invalid top-level await fetch\s*\nconst d = await r\.json\(\);\s*\n\s*const text = d\.choices/g,
  `const _llmBody = JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', messages: [{ role: 'user', content: (system ? system + '\\n\\n' : '') + user }], max_tokens: 1000, temperature: 0.7 });
    const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method: 'POST', headers: { 'Authorization': 'Bearer ' + process.env.GROQ_API_KEY, 'Content-Type': 'application/json' }, body: _llmBody });
    const d = await r.json();
    const text = d.choices`
);

// ── FIX 4: agent-pass inline ─────────────────────────────────────────────────
// Pattern:
//   // ⚠️ removed invalid top-level await fetch
//   const d = await r.json();
//   const text = (d.choices?.[0]...
s = s.replace(
  /\/\/ ⚠️ removed invalid top-level await fetch\s*\nconst d = await r\.json\(\);\s*\n\s*const text = \(d\.choices/g,
  `const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method: 'POST', headers: { 'Authorization': 'Bearer ' + process.env.GROQ_API_KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', messages: [{ role: 'user', content: prompt }], max_tokens: 900, temperature: 0.7 }) });
    const d = await r.json();
    const text = (d.choices`
);

// ── FIX 5: inline try{ routes with raw ──────────────────────────────────────
// Pattern:
//   try { // ⚠️ removed invalid top-level await fetch
//   const raw = await r.json(); const text = (raw.choices?...
s = s.replace(
  /try \{ \/\/ ⚠️ removed invalid top-level await fetch\s*\nconst raw = await r\.json\(\); const text = \(raw\.choices\?\.\[0\]\?\.message\?\.content \|\| ''\)\.replace\(\/```json\|```\/g,''\)\.trim\(\); return res\.json\(safeParseGroq\(text, \{ok:false\}\)\); \}/g,
  `try {
    const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method: 'POST', headers: { 'Authorization': 'Bearer ' + process.env.GROQ_API_KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', messages: [{ role: 'user', content: prompt }], max_tokens: 900, temperature: 0.7 }) });
    const raw = await r.json(); const text = (raw.choices?.[0]?.message?.content || '').replace(/\`\`\`json|\`\`\`/g,'').trim(); return res.json(safeParseGroq(text, {ok:false})); }`
);

// ── FIX 6: evolution/engine GET routes with raw ──────────────────────────────
// Pattern:
//   // ⚠️ removed invalid top-level await fetch
//   const raw = await r.json();  (standalone, not followed by rate_limit check)
s = s.replace(
  /\/\/ ⚠️ removed invalid top-level await fetch\s*\nconst raw = await r\.json\(\);\s*\n\s*if \(!raw\)/g,
  `const r = await fetch('https://api.groq.com/openai/v1/chat/completions', { method: 'POST', headers: { 'Authorization': 'Bearer ' + process.env.GROQ_API_KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ model: process.env.TSM_MODEL || 'llama-3.1-8b-instant', messages: [{ role: 'user', content: prompt }], max_tokens: 900, temperature: 0.7 }) });
  const raw = await r.json();
  if (!raw)`
);

fs.writeFileSync(src_path, s);
console.log('✅ server.js patched');

// Report remaining
const lines = s.split('\n');
const broken = [];
lines.forEach((line, i) => {
  if (line.includes('await r.json') || line.includes('await r\b')) {
    // Check if r was defined nearby (look back 3 lines)
    const context = lines.slice(Math.max(0, i-3), i).join('\n');
    if (!context.includes('const r =') && !context.includes('const r=')) {
      broken.push({ line: i+1, content: line.trim() });
    }
  }
});

if (broken.length === 0) {
  console.log('✅ All broken patterns fixed!');
} else {
  console.log(`⚠️  ${broken.length} potentially broken r.json() calls remaining:`);
  broken.forEach(b => console.log(`   Line ${b.line}: ${b.content}`));
}
