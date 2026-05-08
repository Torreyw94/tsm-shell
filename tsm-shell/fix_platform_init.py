#!/usr/bin/env python3
f = open('/workspaces/tsm-shell/server.js', 'r')
c = f.read()
f.close()

INIT = """
// ===== GLOBAL INIT GUARD =====
global.MUSIC_PLATFORM = global.MUSIC_PLATFORM || {
  artistDNA: {
    status: 'active',
    artist: 'Current Artist',
    styleTerms: ['pain', 'resilience', 'late-night', 'pressure', 'bounce'],
    weights: { cadence: 0.88, emotion: 0.91, structure: 0.76, imagery: 0.82 },
    learnedSongs: []
  },
  agentRuns: [],
  activity: []
};
global.MUSIC_SUITE_STATE = global.MUSIC_SUITE_STATE || {
  artistsOnline: 12, releasesDropping: 3, monthlyStreams: '84M',
  revenueMTD: 847400, pipelineValue: 2400000, aiStatus: 'online'
};
// ===== END GLOBAL INIT GUARD =====
"""

# Insert after first line
lines = c.split('\n')
lines.insert(1, INIT)
c = '\n'.join(lines)

open('/workspaces/tsm-shell/server.js', 'w').write(c)
print('done')
