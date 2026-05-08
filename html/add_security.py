#!/usr/bin/env python3
"""
add_security.py
Adds to server.js:
1. express-rate-limit on all /api routes (60 req/min per IP)
2. Strict rate limit on AI routes (10 req/min per IP)
3. Body size limit (50kb)
4. Basic security headers
5. Fix score delta calculation in index.html
6. Fix Release Decision threshold
7. Auto-fade agent coaching box
8. Fix Start New Song to reset journey
"""

import re

# ── server.js security patch ──────────────────────────────────────────────────
spath = 'server.js'
stxt = open(spath).read()

security_block = """
// ===== SECURITY LAYER =====
const rateLimit = require('express-rate-limit');

// General API rate limit — 60 req/min per IP
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: { ok: false, error: 'Too many requests. Slow down.' }
});

// AI route rate limit — 10 req/min per IP (protects Groq quota)
const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { ok: false, error: 'AI rate limit reached. Wait 60 seconds.' }
});

app.use('/api/', apiLimiter);
app.use('/api/music/revision/run', aiLimiter);
app.use('/api/music/agent-pass', aiLimiter);
app.use('/api/music/chain', aiLimiter);
app.use('/api/ai/query', aiLimiter);

// Body size limit
app.use(express.json({ limit: '50kb' }));
app.use(express.urlencoded({ extended: false, limit: '50kb' }));

// Basic security headers
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});
// ===== END SECURITY LAYER =====

"""

# Insert after app is created
insert_after = "const app = express()"
if insert_after in stxt and 'rateLimit' not in stxt:
    stxt = stxt.replace(insert_after, insert_after + '\n' + security_block)
    print('security block injected')
else:
    print('already has rateLimit or insert point not found')

# Make sure express.json is not duplicated
# Remove any existing bare express.json calls before our new one
stxt = re.sub(r'app\.use\(express\.json\(\)\);?\n', '', stxt)
stxt = re.sub(r'app\.use\(express\.urlencoded\([^)]*\)\);?\n', '', stxt)

open(spath, 'w').write(stxt)
print('server.js done')

# ── index.html UI fixes ───────────────────────────────────────────────────────
path = 'html/music-command/index.html'
txt = open(path).read()

# 1. Fix Release Decision threshold (80%+ = strong, 86%+ = release ready)
txt = txt.replace(
    "const decision=overall>=86?'Release Ready':overall>=74?'Not the best version yet. Let us improve it.':'Scrap / Rework Hook';",
    "const decision=overall>=86?'Release Ready':overall>=80?'Strong version. One more pass could lock it.':overall>=74?'Not the best version yet. Let us improve it.':'Scrap / Rework Hook';"
)

txt = txt.replace(
    "overall>=86?'Strong enough to move toward recording or release planning.': overall>=74?'Not ready yet. One more pass could make this a strong release.':'Hook needs rework before release consideration.'",
    "overall>=86?'Strong enough to move toward recording or release planning.':overall>=80?'Strong version. Refine once more and this could be release-ready.':overall>=74?'Not ready yet. One more pass could make this a strong release.':'Hook needs rework before release consideration.'"
)
print('release decision thresholds fixed')

# 2. Fix score delta — track previous score and calculate real delta
old_render_top = "function render(data,draft,analysis){"
new_render_top = """function render(data,draft,analysis){
  window.__lastScore = window.__currentScore || 0;"""

txt = txt.replace(old_render_top, new_render_top)

txt = txt.replace(
    "const decision=overall>=86?'Release Ready'",
    "window.__currentScore = overall;\n  const delta = overall - (window.__lastScore||overall);\n  const decision=overall>=86?'Release Ready'"
)

txt = txt.replace(
    "document.getElementById('decisionSub').textContent='Score Delta '+(runCount>1?'+4':'+0');",
    "document.getElementById('decisionSub').textContent='Score Delta '+(runCount>1&&delta!==0?(delta>0?'+':'')+delta:'—');"
)

txt = txt.replace(
    "document.getElementById('trajectoryBox').textContent=`${overall>=74?'Rising':'Developing'} · Score Delta ${runCount>1?'+4':'+0'}`;",
    "document.getElementById('trajectoryBox').textContent=`${overall>=74?'Rising':'Developing'} · Score Delta ${runCount>1&&delta!==0?(delta>0?'+':'')+delta:'—'}`;"
)
print('score delta fixed')

# 3. Auto-fade agent coaching box after 4 seconds
old_coach = """    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(()=>el.remove(), 2200);"""
# It appears in two places - the loop-toast
txt = txt.replace(
    "document.body.appendChild(el);\n    setTimeout(()=>el.remove(), 2200);",
    "document.body.appendChild(el);\n    setTimeout(()=>el.remove(), 2200);"
)

# Fix the ai-coach-box to auto-fade
old_coach_box = "el.textContent = msg;\n  }"
new_coach_box = """el.textContent = msg;
    clearTimeout(el._fadeTimer);
    el._fadeTimer = setTimeout(()=>{ if(el.parentNode) el.parentNode.removeChild(el); }, 4000);
  }"""
txt = txt.replace(old_coach_box, new_coach_box)
print('coach box auto-fade fixed')

# 4. Fix Start New Song to reset journey bar
old_start_new = 'window.__pickedVersion="";window.__refinedVersion="";window.__lockedHook="";'
new_start_new = 'window.__pickedVersion="";window.__refinedVersion="";window.__lockedHook="";window.__journeyStep=1;if(typeof updateBar==="function")updateBar();if(typeof showDraft==="function")showDraft();'
txt = txt.replace(old_start_new, new_start_new)
print('Start New Song reset fixed')

open(path, 'w').write(txt)
print('index.html done')
print('\nAll security + UI fixes applied.')
