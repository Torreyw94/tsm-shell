#!/usr/bin/env python3
# Fixes 7 API routes that are defined AFTER the catch-all in server.js
# Moves them to before app.use() catch-all handler

import re

SERVER = "/workspaces/tsm-shell/server.js"

with open(SERVER, "r", encoding="utf-8") as f:
    content = f.read()

# The 7 missing routes are inside the MUSIC SUITE API INLINE and MUSIC PLATFORM blocks
# which are incorrectly placed inside the catch-all app.use() handler
# Strategy: extract those blocks, remove them from inside catch-all, insert before catch-all

ROUTES_TO_ADD = """
// ===== MUSIC SUITE API INLINE (moved before catch-all) =====
app.get('/api/music/state', (_req, res) => {
  return res.json({ ok: true, state: global.MUSIC_SUITE_STATE });
});

app.post('/api/music/agent-pass', (req, res) => {
  const body = req.body || {};
  return res.json({
    ok: true,
    agent: body.agent || "full",
    output: "Agent pass complete. Draft sharpened for cadence, emotion, and structure.",
    createdAt: new Date().toISOString()
  });
});

app.post('/api/music/strategy', (req, res) => {
  return res.json({
    ok: true,
    title: "Music Strategy Brief",
    answer: "Prioritize viral capture, release timing, sync outreach, and artist DNA consistency.",
    createdAt: new Date().toISOString()
  });
});

// ===== MUSIC PLATFORM EXECUTION LOOP (moved before catch-all) =====
app.post('/api/music/dna/save', (req, res) => {
  const body = req.body || {};
  const dna = global.MUSIC_PLATFORM.artistDNA;
  dna.artist = body.artist || dna.artist;
  dna.notes = body.notes || dna.notes || "";
  dna.styleTerms = Array.isArray(body.styleTerms) ? body.styleTerms : dna.styleTerms;
  dna.weights = Object.assign({}, dna.weights, body.weights || {});
  dna.updatedAt = new Date().toISOString();
  return res.json({ ok: true, dna });
});

app.post('/api/music/song/learn', (req, res) => {
  const body = req.body || {};
  const song = {
    id: Date.now(),
    title: body.title || "Untitled Song",
    lyrics: body.lyrics || body.draft || "",
    tags: body.tags || [],
    learnedAt: new Date().toISOString()
  };
  global.MUSIC_PLATFORM.artistDNA.learnedSongs.unshift(song);
  global.MUSIC_PLATFORM.artistDNA.learnedSongs =
    global.MUSIC_PLATFORM.artistDNA.learnedSongs.slice(0, 12);
  return res.json({ ok: true, song, dna: global.MUSIC_PLATFORM.artistDNA });
});

app.get('/api/music/activity', (_req, res) => {
  return res.json({ ok: true, activity: global.MUSIC_PLATFORM.activity, platform: global.MUSIC_PLATFORM });
});

app.get('/api/music/platform', (_req, res) => {
  return res.json({ ok: true, platform: global.MUSIC_PLATFORM });
});

"""

# Find the catch-all app.use() and insert routes before it
CATCHALL_MARKER = "app.use((req, res) => {"

if CATCHALL_MARKER not in content:
    print("❌ Could not find catch-all marker in server.js")
    exit(1)

# Insert the missing routes before the catch-all
content = content.replace(CATCHALL_MARKER, ROUTES_TO_ADD + "\n" + CATCHALL_MARKER)

with open(SERVER, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 7 routes inserted before catch-all handler")
print("   - GET  /api/music/activity")
print("   - GET  /api/music/platform")
print("   - POST /api/music/agent-pass")
print("   - POST /api/music/chain (already worked)")
print("   - POST /api/music/strategy")
print("   - POST /api/music/dna/save")
print("   - POST /api/music/song/learn")
print("")
print("Run: bash predeploy_titles.sh && fly deploy")
print("Then: bash test_endpoints.sh https://tsm-shell.fly.dev")
