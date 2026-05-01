const express = require('express');
const path = require('path');
const fs = require('fs');
const https = require('https');

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());

// ── DATA STORE ────────────────────────────────────────────────────────────────
const HC_DATA_DIR = path.join(__dirname, 'data', 'hc-strategist');
const HC_REPORTS_FILE = path.join(HC_DATA_DIR, 'reports.json');
const HC_NODE_STATE_FILE = path.join(HC_DATA_DIR, 'node-state.json');
const HC_PROFILES_FILE = path.join(HC_DATA_DIR, 'profiles.json');

function ensureStore() {
  fs.mkdirSync(HC_DATA_DIR, { recursive: true });
  if (!fs.existsSync(HC_REPORTS_FILE)) fs.writeFileSync(HC_REPORTS_FILE, '[]', 'utf8');
  if (!fs.existsSync(HC_NODE_STATE_FILE)) fs.writeFileSync(HC_NODE_STATE_FILE, '{}', 'utf8');
  if (!fs.existsSync(HC_PROFILES_FILE)) {
    fs.writeFileSync(HC_PROFILES_FILE, JSON.stringify([
      { id: "honor", name: "HonorHealth", system: "HonorHealth", locations: ["All", "Scottsdale - Shea", "Osborn"] },
      { id: "banner", name: "Banner", system: "Banner", locations: ["All"] },
      { id: "dignity", name: "Dignity", system: "Dignity", locations: ["All"] }
    ], null, 2), 'utf8');
  }
}
ensureStore();

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function writeJson(file, value) {
  fs.writeFileSync(file, JSON.stringify(value, null, 2), 'utf8');
}

// ── CORE STATUS ───────────────────────────────────────────────────────────────
app.get('/api/status', (req, res) => {
  res.json({
    status: "SOVEREIGN ONLINE",
    valuation: "$600,000",
    bridge: "CONNECTED"
  });
});

// ── HC REPORTS ────────────────────────────────────────────────────────────────
app.get('/api/hc/reports', (req, res) => {
  const reports = readJson(HC_REPORTS_FILE, []);
  res.json({ ok: true, count: reports.length, reports });
});

app.post('/api/hc/reports', (req, res) => {
  const reports = readJson(HC_REPORTS_FILE, []);
  const now = new Date().toISOString();
  const report = {
    id: `rpt_${Date.now()}`,
    title: req.body.title || 'Untitled Report',
    company: req.body.company || 'General Healthcare',
    query: req.body.query || '',
    summary: req.body.summary || '',
    nodeResults: req.body.nodeResults || {},
    createdAt: now,
    updatedAt: now
  };
  reports.unshift(report);
  writeJson(HC_REPORTS_FILE, reports.slice(0, 300));
  res.json({ ok: true, report });
});

app.delete('/api/hc/reports/:id', (req, res) => {
  const reports = readJson(HC_REPORTS_FILE, []);
  const next = reports.filter(r => r.id !== req.params.id);
  writeJson(HC_REPORTS_FILE, next);
  res.json({ ok: true });
});

// ── HC NODE STATE ─────────────────────────────────────────────────────────────
app.get('/api/hc/nodes', (req, res) => {
  const state = readJson(HC_NODE_STATE_FILE, {});
  res.json({ ok: true, state, generatedAt: new Date().toISOString() });
});

app.post('/api/hc/nodes/:nodeKey', (req, res) => {
  const state = readJson(HC_NODE_STATE_FILE, {});
  state[req.params.nodeKey] = {
    ...(state[req.params.nodeKey] || {}),
    ...req.body,
    nodeKey: req.params.nodeKey,
    updatedAt: new Date().toISOString()
  };
  writeJson(HC_NODE_STATE_FILE, state);
  res.json({ ok: true, node: state[req.params.nodeKey] });
});

// ── HC ENTERPRISE PROFILES / FILTER / BNCA / ASK ─────────────────────────────
app.get('/api/hc/profiles', (req, res) => {
  res.json({ ok: true, profiles: readJson(HC_PROFILES_FILE, []) });
});

app.get('/api/hc/nodes/filter', (req, res) => {
  const { system = '', location = '' } = req.query;
  const state = readJson(HC_NODE_STATE_FILE, {});
  const filtered = Object.fromEntries(
    Object.entries(state).filter(([_, v]) => {
      return (!system || v.system === system) &&
             (!location || location === 'All' || v.location === location);
    })
  );
  res.json({ ok: true, state: filtered });
});

app.post('/api/hc/bnca', (req, res) => {
  const { system = '', location = '' } = req.body || {};
  const state = readJson(HC_NODE_STATE_FILE, {});

  const nodes = Object.values(state).filter(v =>
    (!system || v.system === system) &&
    (!location || location === 'All' || v.location === location)
  );

  const top = nodes.find(v => v.findings)?.findings || 'Operational drag across nodes';

  res.json({
    ok: true,
    bnca: {
      system,
      location,
      topIssue: top,
      whyItMatters: 'Revenue + throughput pressure',
      bestNextCourseOfAction: [
        'Clear high-value backlog',
        'Escalate auth delays',
        'Rebalance intake + billing'
      ],
      ownerLanes: ['Operations', 'Billing', 'Insurance'],
      confidence: '88%'
    }
  });
});

app.post('/api/hc/ask', async (req, res) => {
  try {
    const { query = '', system = '', location = '' } = req.body || {};
    const state = readJson(HC_NODE_STATE_FILE, {});

    const context = Object.entries(state)
      .filter(([_, v]) =>
        (!system || v.system === system) &&
        (!location || location === 'All' || v.location === location)
      )
      .map(([k, v]) => `NODE:${k}
SYSTEM:${v.system || ''}
LOCATION:${v.location || ''}
FINDINGS:${v.findings || ''}
SUMMARY:${v.summary || ''}
BNCA:${v.bnca || ''}
QUEUE:${v.queueDepth ?? ''}
NOSHOW:${v.noShowRate ?? ''}
BACKLOG:${v.intakeBacklog ?? ''}
STAFFING:${v.staffingCoverage ?? ''}`)
      .join('\n\n');

    if (!process.env.GROQ_API_KEY) {
      return res.json({
        ok: true,
        content: `TOP ISSUE
${context || 'No data'}

ACTION
Fix backlog + auth + throughput`
      });
    }

    const payload = JSON.stringify({
      model: 'llama-3.3-70b-versatile',
      max_tokens: 900,
      stream: false,
      messages: [
        {
          role: 'system',
          content: 'You are a healthcare strategist. Be specific. Use live node metrics and avoid generic language.'
        },
        {
          role: 'user',
          content: `${query}\n\n${context}`
        }
      ]
    });

    const options = {
      hostname: 'api.groq.com',
      path: '/openai/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + process.env.GROQ_API_KEY,
        'Content-Length': Buffer.byteLength(payload)
      }
    };

    const r = https.request(options, res2 => {
      let b = '';
      res2.on('data', d => b += d);
      res2.on('end', () => {
        try {
          const parsed = JSON.parse(b);
          const out = parsed?.choices?.[0]?.message?.content || 'No AI response';
          res.json({ ok: true, content: out });
        } catch {
          res.status(500).json({ ok: false, error: 'Invalid AI response' });
        }
      });
    });

    r.on('error', e => res.status(500).json({ ok: false, error: e.message }));
    r.write(payload);
    r.end();
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// ── STATIC ────────────────────────────────────────────────────────────────────
app.use('/html/suite', express.static(path.join(__dirname, 'html', 'suite')));
app.use('/html/healthcare', express.static(path.join(__dirname, 'html', 'healthcare')));
app.use('/html/hc-strategist', express.static(path.join(__dirname, 'html', 'hc-strategist')));
app.use('/', express.static(path.join(__dirname, 'html')));

// catch-all LAST
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'html', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`TSM Node API running on ${PORT}`);
});
