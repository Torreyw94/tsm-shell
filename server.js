/**
 * server.js — TSM Shell multi-suite server
 * Serves: construction-suite, finops-suite, healthcare, tsm-insurance, music-command
 * Compatible with: GitHub Codespaces, Fly.io
 *
 * Usage:
 *   node server.js
 *
 * Env vars:
 *   PORT        — default 3000 (Fly.io sets this automatically)
 *   NODE_ENV    — set to "production" on Fly.io
 */

const express = require("express");
const path = require("path");
const fs = require("fs");

const app = express();
const PORT = process.env.PORT || 3000;

// ─── Root of all HTML suites ────────────────────────────────────────────────
// Adjust HTML_ROOT if your working directory differs.
// Assumes this server.js lives alongside or above the html/ folder.
const HTML_ROOT = path.join(__dirname, "html");

// ─── Health check (required by Fly.io) ──────────────────────────────────────
app.get("/health", (_req, res) => res.json({ status: "ok" }));

// ─── Suite routes ────────────────────────────────────────────────────────────
const suites = [
  {
    route: "/construction",
    dir: "construction-suite",
    index: "construction-hub.html",
  },
  {
    route: "/finops",
    dir: "finops-suite",
    index: "financial-ui.html",
  },
  {
    route: "/healthcare",
    dir: "healthcare",
    index: "index.html",
  },
  {
    route: "/insurance",
    dir: "tsm-insurance",
    index: "agents-ins.html",
  },
  {
    route: "/music",
    dir: "music-command",
    index: "index.html",
  },
];

suites.forEach(({ route, dir, index }) => {
  const suiteDir = path.join(HTML_ROOT, dir);

  // Sanity-check the directory exists at startup
  if (!fs.existsSync(suiteDir)) {
    console.warn(`⚠️  Suite directory not found: ${suiteDir}`);
  }

  // Redirect bare route → trailing slash so relative paths resolve correctly
  app.get(route, (_req, res) => res.redirect(route + "/"));

  // Redirect root of suite → default index file
  app.get(route + "/", (_req, res) => {
    res.sendFile(path.join(suiteDir, index), (err) => {
      if (err) {
        res.status(404).send(`Index not found for suite "${dir}": ${index}`);
      }
    });
  });

  // Serve all static assets under the suite (html, js, css, json, etc.)
  app.use(route + "/", express.static(suiteDir, { extensions: ["html"] }));

  console.log(`✅  /${route.slice(1)} → ${suiteDir}`);
});

// ─── Root redirect → simple landing page ─────────────────────────────────────
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
          gap:1rem;width:min(800px,90vw)}
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
    <a class="card" href="/construction/">
      <h2>🏗️ Construction</h2>
      <p>Construction command, legal, financial &amp; compliance tools</p>
    </a>
    <a class="card" href="/finops/">
      <h2>💰 FinOps Suite</h2>
      <p>Financial operations, tax &amp; compliance dashboard</p>
    </a>
    <a class="card" href="/healthcare/">
      <h2>🏥 Healthcare</h2>
      <p>15-node sovereign mesh: billing, insurance, pharmacy &amp; more</p>
    </a>
    <a class="card" href="/insurance/">
      <h2>🛡️ TSM Insurance</h2>
      <p>Agent portal, AZ insurance, DME, pricing &amp; legal</p>
    </a>
    <a class="card" href="/music/">
      <h2>🎵 Music Command</h2>
      <p>Music app, demo conductor, marketing &amp; presentation tools</p>
    </a>
  </div>
</body>
</html>`);
});

// ─── 404 fallback ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).send(`<pre>404 — Not found: ${req.path}</pre>`);
});

// ─── Start ────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n🚀 TSM Shell running on http://localhost:${PORT}`);
  console.log(`   /construction  → construction-suite`);
  console.log(`   /finops        → finops-suite`);
  console.log(`   /healthcare    → healthcare`);
  console.log(`   /insurance     → tsm-insurance`);
  console.log(`   /music         → music-command\n`);
});
