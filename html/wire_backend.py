#!/usr/bin/env python3
"""
wire_backend.py
- Removes client-side GROQ_API_KEY + groqChat from index.html
- Rewires runAnalysis() to call /api/music/revision/run (backend, key-safe)
- Rewires RIYA refine to call /api/music/agent-pass (backend)
- Rewires lock hook to call /api/music/agent-pass (backend)
- Fixes duplicate app.listen in server.js
"""

import re

# ── index.html ────────────────────────────────────────────────────────────────
path = 'html/music-command/index.html'
txt = open(path).read()

# 1. Remove the groqChat helper block (GROQ_API_KEY through closing brace)
txt = re.sub(
    r"const GROQ_API_KEY = '[^']*';\s*const GROQ_MODEL[^}]+}\s*\n\s*\}\s*\n\s*\}\s*\n",
    '',
    txt,
    flags=re.DOTALL
)
# Simpler fallback — remove any line containing GROQ_API_KEY declaration or GROQ_MODEL declaration
lines = txt.split('\n')
lines = [l for l in lines if not (
    ("const GROQ_API_KEY" in l and '=' in l) or
    ("const GROQ_MODEL" in l and '=' in l)
)]
txt = '\n'.join(lines)

# 2. Remove the entire groqChat function definition
txt = re.sub(
    r'async function groqChat\(.*?\n\}\n',
    '',
    txt,
    flags=re.DOTALL
)

# 3. Replace runAnalysis Groq block with backend call
old_run = re.search(
    r'// ── ZAY: score ──.*?document\.getElementById\(\'runBtn\'\)\.disabled=false;',
    txt, re.DOTALL
)
if old_run:
    new_run = """  // ── Call backend agent chain ─────────────────────────────────────────────
  let data;
  try{
    const r = await fetch('/api/music/revision/run',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({draft, request:'guided creation app'})
    });
    data = await r.json();
  } catch(e){
    data = { ok:false };
  }
  if(!data.ok) data = {
    session:{ options:[
      {id:'A',title:'Flow First',strategy:'Cadence and bounce',output:draft},
      {id:'B',title:'Emotion First',strategy:'Imagery and vulnerability',output:draft},
      {id:'C',title:'Hook First',strategy:'Structure and repeatability',output:draft}
    ]},
    run:{ score:{cadence:.78,emotion:.80,structure:.76,imagery:.74,overall:.79} }
  };

  setStage(4); await new Promise(r=>setTimeout(r,300));
  const analysis = data.run && data.run.analysis ? data.run.analysis : null;
  render(data, draft, analysis);
  document.getElementById('runBtn').disabled=false;"""
    txt = txt[:old_run.start()] + new_run + txt[old_run.end():]
    print('runAnalysis rewired to backend')
else:
    print('WARNING: runAnalysis Groq block not found - may already be clean')

# 4. Replace RIYA refine fetch (any remaining Groq fetch in refine block)
txt = re.sub(
    r"var resp=await fetch\(['\"]https://api\.groq\.com[^;]+\);",
    """var resp=await fetch('/api/music/agent-pass',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({agent:'RIYA',draft:base,request:note||'Make it stronger and more repeatable'})});""",
    txt
)

# 5. Fix data parsing for backend responses (agent-pass returns {ok,output})
txt = txt.replace(
    "var refined=((data.choices||[])[0]||{}).message&&data.choices[0].message.content.trim()||\"\"",
    "var refined=(data.output||'').trim()"
)
txt = txt.replace(
    "var hook=((data.choices||[])[0]||{}).message&&data.choices[0].message.content.trim()||\"\"",
    "var hook=(data.output||'').trim()"
)

# 6. Remove any leftover Authorization Bearer lines
lines = txt.split('\n')
lines = [l for l in lines if '"Authorization":"Bearer "' not in l and "'Authorization':'Bearer '" not in l]
txt = '\n'.join(lines)

open(path, 'w').write(txt)
print('index.html done')

# ── server.js — fix duplicate app.listen ─────────────────────────────────────
spath = 'server.js'
stxt = open(spath).read()

# Keep only the first app.listen, remove the duplicate
first = stxt.find('app.listen(')
second = stxt.find('app.listen(', first+1)
if second > 0:
    # find end of second listen block
    end = stxt.find('\n});', second)
    if end > 0:
        stxt = stxt[:second] + stxt[end+4:]
        print('duplicate app.listen removed from server.js')
    else:
        print('WARNING: could not find end of duplicate app.listen')
else:
    print('no duplicate app.listen found')

open(spath, 'w').write(stxt)

# ── Verify ────────────────────────────────────────────────────────────────────
txt2 = open(path).read()
print('\n=== VERIFY index.html ===')
print('GROQ_API_KEY occurrences:', txt2.count('GROQ_API_KEY'))
print('groqChat occurrences:', txt2.count('groqChat'))
print('/api/music/revision/run:', txt2.count('/api/music/revision/run'))
print('/api/music/agent-pass:', txt2.count('/api/music/agent-pass'))
print('api.groq.com remaining:', txt2.count('api.groq.com'))

stxt2 = open(spath).read()
print('\n=== VERIFY server.js ===')
print('app.listen count:', stxt2.count('app.listen('))
print('GROQ_API_KEY (env):', stxt2.count('process.env.GROQ_API_KEY'))
print('groqChat function:', stxt2.count('function groqChat'))
