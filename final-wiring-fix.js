const fs = require('fs');
const path = 'html/construction-suite/document-showcase.html';
let content = fs.readFileSync(path, 'utf8');

// Replace the placeholder or incorrect routes with the actual server endpoint
content = content.replace(
    /fetch\("https:\/\/tsm-shell\.fly\.dev\/api\/v1\/ask"/g, 
    'fetch("https://tsm-shell.fly.dev/api/hc/ask"'
);

fs.writeFileSync(path, content);
