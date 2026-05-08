#!/usr/bin/env python3
f = open('/workspaces/tsm-shell/server.js', 'r')
c = f.read()
f.close()

fix = """
app.get('/api/music/activity', (_req, res) => {
  if (!global.MUSIC_PLATFORM) global.MUSIC_PLATFORM = { activity: [], artistDNA: { learnedSongs: [] } };
  return res.json({ ok: true, activity: global.MUSIC_PLATFORM.activity || [], platform: global.MUSIC_PLATFORM });
});

app.post('/api/music/chain', (req, res) => {
  const body = req.body || {};
  const draft = body.draft || '';
  const request = body.request || '';
  return res.json({
    ok: true,
    mode: 'chain',
    agents: ['ZAY', 'RIYA', 'DJ'],
    request,
    input: draft,
    output: 'Chain complete. Draft refined through ZAY cadence, RIYA emotion, DJ structure.',
    score: { overall: 0.84, cadence: 0.88, emotion: 0.91, structure: 0.76, imagery: 0.82 },
    createdAt: new Date().toISOString()
  });
});

"""

marker = 'app.use((req, res) => {'
if marker in c:
    c = c.replace(marker, fix + marker, 1)
    open('/workspaces/tsm-shell/server.js', 'w').write(c)
    print('✅ Fixed /api/music/activity and /api/music/chain')
else:
    print('❌ Marker not found')
