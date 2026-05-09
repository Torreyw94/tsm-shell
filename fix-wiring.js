const fs = require('fs');
const path = 'html/construction-suite/document-showcase.html';
let content = fs.readFileSync(path, 'utf8');

// Update the fetch URL to check for common API prefixes if /ask fails
content = content.replace(
    /fetch\("https:\/\/tsm-shell\.fly\.dev\/ask"/g, 
    'fetch("https://tsm-shell.fly.dev/api/v1/ask"'
);

fs.writeFileSync(path, content);
