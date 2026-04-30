const express = require("express");
const path = require("path");
const fs = require("fs");

const app = express();
const PORT = process.env.PORT || 8080;
const HTML_ROOT = path.join(__dirname, "html");

app.get("/health", (_req, res) => res.json({ status: "ok" }));

const suites = [
  { route: "/construction", dir: "construction-suite",  index: "construction-hub.html" },
  { route: "/finops",       dir: "finops-suite",        index: "finops-presentation/index.html" },
  { route: "/healthcare",   dir: "healthcare",           index: "index.html" },
  { route: "/insurance",    dir: "tsm-insurance",        index: "ins-presentation.html" },
  { route: "/music",        dir: "music-command",        index: "index.html" },
];

suites.forEach(({ route, dir, index }) => {
  const suiteDir = path.join(HTML_ROOT, dir);
  if (!fs.existsSync(suiteDir)) console.warn(`⚠️  Not found: ${suiteDir}`);
  const serveIndex = (_req, res) => {
    res.sendFile(path.join(suiteDir, index), (err) => {
      if (err) res.status(404).send(`Index not found: ${index}`);
    });
  };
  app.get(route, serveIndex);
  app.get(route + "/", serveIndex);
  app.use(route + "/", express.static(suiteDir, { extensions: ["html"] }));
  console.log(`✅  ${route} → ${dir}/${index}`);
});

app.get("/", (_req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>TSM Shell</title>
  <style>
    body{font-family:system-ui,sans-serif;background:#0d1117;color:#e6edf3;
         display:flex;flex-direction:column;align-items:center;
         justify-content:center;min-height:100vh;margin:0}
    h1{font-size:2rem;margin-bottom:.5rem}
    p{color:#8b949e;margin-bottom:2rem}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));
          gap:1rem;width:min(900px,90vw)}
    a.card{background:#161b22;border:1px solid #30363d;border-radius:12px;
           padding:1.5rem;text-decoration:none;color:inherit;transition:.2s}
    a.card:hover{border-color:#58a6ff;background:#1c2128}
    a.card h2{margin:0 0 .4rem;font-size:1.1rem}
    a.card p{margin:0;font-size:.85rem;color:#8b949e}
  </style>
</head>
<body>
  <h1>TSM Shell</h1>
  <p>Select a suite to continue</p>
  <div class="grid">
    <a class="card" href="/construction"><h2>🏗️ Construction</h2><p>Command, legal, financial &amp; compliance</p></a>
    <a class="card" href="/finops"><h2>💰 FinOps Suite</h2><p>Financial operations, tax &amp; compliance</p></a>
    <a class="card" href="/healthcare"><h2>🏥 Healthcare</h2><p>15-node mesh: billing, insurance, pharmacy</p></a>
    <a class="card" href="/insurance"><h2>🛡️ TSM Insurance</h2><p>Agent portal, AZ, DME, pricing &amp; legal</p></a>
    <a class="card" href="/music"><h2>🎵 Music Command</h2><p>App, demo conductor, marketing &amp; presentation</p></a>
  </div>
</body>
</html>`);
});

app.use((req, res) => res.status(404).send(`<pre>404 — Not found: ${req.path}</pre>`));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`\n🚀 TSM Shell on http://0.0.0.0:${PORT}`);
  suites.forEach(s => console.log(`   ${s.route} → ${s.dir}/${s.index}`));
  console.log();
});
