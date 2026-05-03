#!/usr/bin/env node
/**
 * final-layout-fix.js — ONE SHOT, no more iterations
 * Targets exact selectors found in the HTML
 */
const fs = require('fs');
let html = fs.readFileSync('html/music-command/index.html', 'utf8');

// 1. Remove ALL previous injected style/script blocks we added
const REMOVE_IDS = [
  'tsm-layout-v5', 'tsm-final-layout-fix', 'tsm-textarea-visibility',
  'tsm-panel-scroll-fix', 'tsm-workflow-steps', 'tsm-layout-fix',
  'tsm-coach-v4-css', 'tsm-guide-v4'
];
REMOVE_IDS.forEach(id => {
  html = html.replace(new RegExp(`<style id="${id}">[\\s\\S]*?</style>`, 'g'), '');
  html = html.replace(new RegExp(`<script id="${id}">[\\s\\S]*?</script>`, 'g'), '');
});
console.log('✓ Removed old injected blocks');

// 2. Fix the TWO conflicting .content rules in the original CSS
// Line 298: first .content rule — make it scrollable
html = html.replace(
  '.content {\n    overflow-y: auto;\n    overflow-x: hidden;\n    padding: 24px;\n    scrollbar-width: thin;\n    scrollbar-color: var(--bg4) transparent;\n    display: flex;\n    flex-direction: column;\n  }',
  '.content {\n    overflow-y: auto;\n    overflow-x: hidden;\n    padding: 24px;\n    scrollbar-width: thin;\n    scrollbar-color: var(--bg4) transparent;\n    display: block;\n  }'
);

// 3. Fix .panel.active — use block not flex so height is natural
html = html.replace(
  '.panel { display: none; }\n  .panel.active { display: flex; flex-direction: column; flex: none; min-height: 100%; }',
  '.panel { display: none; }\n  .panel.active { display: block; }'
);
html = html.replace(
  '.panel { display: none; }\n  .panel.active { display: flex; flex-direction: column; flex: 1; }',
  '.panel { display: none; }\n  .panel.active { display: block; }'
);

// 4. Fix #panel-draft specific rule
html = html.replace(
  '#panel-draft { display: flex; flex-direction: column; flex: none; overflow: visible; }',
  '#panel-draft { display: block; overflow: visible; }'
);
html = html.replace(
  '#panel-draft { display: flex; flex-direction: column; flex: 1; overflow: hidden; }',
  '#panel-draft { display: block; overflow: visible; }'
);

// 5. Fix the second .content rule at line 1249
html = html.replace(
  /(<style[^>]*>[\s\S]*?)\.content \{\s*\n\s*overflow-y: auto !important;[\s\S]*?\}/,
  (m) => m // leave it, we'll override below
);

// 6. Inject ONE clean override after all existing CSS
const OVERRIDE = `
<style id="tsm-one-shot-layout">
/* FINAL LAYOUT FIX — targets .content which is the real scrollable wrapper */
html, body { height: 100%; overflow: hidden; }

.app { height: 100vh; display: flex; overflow: hidden; }
.sidebar { flex-shrink: 0; overflow-y: auto; }

.main {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-width: 0;
}

/* nav/topbar stays fixed height */
nav { flex-shrink: 0; }

/* .content is the scrollable area */
.content {
  flex: 1 !important;
  overflow-y: auto !important;
  overflow-x: hidden !important;
  display: block !important;
  padding: 24px !important;
  min-height: 0 !important;
}

/* Panels just render naturally in document flow */
.panel { display: none !important; }
.panel.active {
  display: block !important;
  overflow: visible !important;
}

/* Draft textarea visible */
#draft-input {
  min-height: 200px;
  border: 1px solid rgba(255,255,255,0.1);
  background: rgba(255,255,255,0.03);
  color: rgba(255,255,255,0.9);
}
#draft-input::placeholder { color: rgba(255,255,255,0.2); }

/* Evolution panel — no margin-top:auto pushing to bottom */
#music-evolution-panel { margin-top: 16px !important; }

/* Guide bar stays compact */
.tsm-guide-bar { margin-bottom: 12px; }
.tsm-workflow { margin-bottom: 12px; }
</style>
`;

html = html.replace('</head>', OVERRIDE + '\n</head>');
console.log('✓ One-shot layout override injected');

fs.writeFileSync('html/music-command/index.html', html, 'utf8');
console.log('✓ Done — deploy with: fly deploy --local-only --app tsm-shell');
