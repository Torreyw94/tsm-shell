const fs = require('fs');
let src = fs.readFileSync('server.js', 'utf8');

// Fix safeParseGroq to strip unescaped newlines inside JSON strings
// before attempting to parse — this is what breaks revision/generate
const oldHelper = `// safeParseGroq — extracts valid JSON, handles rate limits and truncation
function safeParseGroq(text, fallback = {}) {
  try {
    const clean = text.replace(/\`\`\`json|\`\`\`/g, '').trim();
    return JSON.parse(clean);
  } catch(_) {
    try {
      const start = text.indexOf('{');
      const end = text.lastIndexOf('}');
      if (start !== -1 && end !== -1 && end > start) {
        return JSON.parse(text.slice(start, end + 1));
      }
    } catch(_) {}
    return { ok: false, error: 'parse_failed', raw: text.slice(0, 200), ...fallback };
  }
}`;

const newHelper = `// safeParseGroq — extracts valid JSON, handles rate limits, newlines, and truncation
function safeParseGroq(text, fallback = {}) {
  function cleanJson(str) {
    // remove markdown fences
    str = str.replace(/\`\`\`json|\`\`\`/g, '').trim();
    // escape unescaped newlines/tabs inside JSON string values
    str = str.replace(/"((?:[^"\\\\]|\\\\.)*)"/g, (match) =>
      match.replace(/\\n/g, '\\\\n').replace(/\\r/g, '\\\\r').replace(/\\t/g, '\\\\t')
           .replace(/(?<!\\\\)\\n/g, '\\\\n').replace(/(?<!\\\\)\\r/g, '\\\\r')
    );
    // simpler fallback: replace literal newlines inside strings
    str = str.replace(/([":,\\[{]\\s*)\\n(\\s*)/g, '$1 $2');
    return str;
  }
  try {
    return JSON.parse(cleanJson(text));
  } catch(_) {
    try {
      // extract largest {...} block and clean it
      const start = text.indexOf('{');
      const end = text.lastIndexOf('}');
      if (start !== -1 && end !== -1 && end > start) {
        const block = text.slice(start, end + 1);
        // replace literal newlines with \\n so JSON.parse accepts them
        const safe = block.replace(/\\r?\\n/g, '\\\\n').replace(/\\t/g, '\\\\t');
        return JSON.parse(safe);
      }
    } catch(_) {}
    return { ok: false, error: 'parse_failed', raw: text.slice(0, 200), ...fallback };
  }
}`;

if (src.includes(oldHelper)) {
  src = src.replace(oldHelper, newHelper);
  console.log('✓ safeParseGroq updated with newline sanitizer');
} else {
  // try partial match on the function signature
  const sigStart = src.indexOf('// safeParseGroq — extracts valid JSON, handles rate limits and truncation');
  const sigEnd = src.indexOf('\n// groqFetch');
  if (sigStart !== -1 && sigEnd !== -1) {
    src = src.slice(0, sigStart) + newHelper + src.slice(sigEnd);
    console.log('✓ safeParseGroq replaced via signature match');
  } else {
    console.error('✗ Could not find safeParseGroq — check server.js manually');
    process.exit(1);
  }
}

fs.writeFileSync('server.js', src);
console.log('✓ Written. Run: node --check server.js && touch server.js && fly deploy --local-only --app tsm-shell');
