// Run from /workspaces/tsm-shell:  node tsm-hub-fix.js

const fs = require('fs');
const path = require('path');

const HUB = path.join('html', 'index.html');
if (!fs.existsSync(HUB)) { console.error('NOT FOUND:', HUB); process.exit(1); }

let src = fs.readFileSync(HUB, 'utf8');

// FIX: appUrl — point HC_NODES and HTML_FILES to /html/ not /apps/
src = src.replace(
  `if (HC_NODES.has(name))   return '/apps/' + name + '/index.html';`,
  `if (HC_NODES.has(name))   return '/html/' + name + '/index.html';`
);
src = src.replace(
  `if (HTML_FILES.has(name)) return '/apps/' + name + '.html';`,
  `if (HTML_FILES.has(name)) return '/html/' + name + '.html';`
);
src = src.replace(
  `return '/apps/' + name + '/';`,
  `return '/html/' + name + '/';`
);

fs.writeFileSync(HUB, src, 'utf8');
console.log('✔ fixed: html/index.html — appUrl now routes to /html/');
