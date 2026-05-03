const fs = require('fs');
let src = fs.readFileSync('server.js', 'utf8');

let changeCount = 0;

// FIX 1: /api/music/engine — frontend calls GET (no body), server was POST
// Convert to GET, params come from query string instead of body
src = src.replace(
  `app['post']('/api/music/engine', async (req, res) => {
  const { action='', lyrics='', config={} } = req.body;`,
  `app['get']('/api/music/engine', async (req, res) => {
  const { action='', lyrics='', config='' } = req.query;`
);
if (src.includes(`app['get']('/api/music/engine'`)) {
  console.log('✓ FIX 1: /api/music/engine → GET');
  changeCount++;
} else {
  console.error('✗ FIX 1 FAILED — check server.js manually');
}

// FIX 2: /api/music/evolution — frontend calls GET (no body), server was POST
// Convert to GET
src = src.replace(
  `app['post']('/api/music/evolution', async (req, res) => {
  const { lyrics='', generations=1, target='' } = req.body;`,
  `app['get']('/api/music/evolution', async (req, res) => {
  const { lyrics='', generations=1, target='' } = req.query;`
);
if (src.includes(`app['get']('/api/music/evolution'`)) {
  console.log('✓ FIX 2: /api/music/evolution → GET');
  changeCount++;
} else {
  console.error('✗ FIX 2 FAILED — check server.js manually');
}

// FIX 3: /api/music/demo/view — frontend calls POST (line 3154 in app.html), server was GET
src = src.replace(
  `app['get']('/api/music/demo/view', (req, res) => { const { demo_token='' } = req.query;`,
  `app['post']('/api/music/demo/view', (req, res) => { const { demo_token='' } = req.body?.demo_token ? req.body : req.query;`
);
if (src.includes(`app['post']('/api/music/demo/view'`)) {
  console.log('✓ FIX 3: /api/music/demo/view → POST');
  changeCount++;
} else {
  console.error('✗ FIX 3 FAILED — check server.js manually');
}

if (changeCount === 3) {
  fs.writeFileSync('server.js', src);
  console.log('\n✓ All 3 fixes applied. Run: node --check server.js');
} else {
  console.error(`\n✗ Only ${changeCount}/3 fixes applied. NOT writing file.`);
  process.exit(1);
}
