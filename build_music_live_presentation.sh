#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
mkdir -p backups/music_live_presentation

FILE="html/music-command/presentation-live.html"
[ -f "$FILE" ] && cp -f "$FILE" "backups/music_live_presentation/presentation-live.$(date +%Y%m%d-%H%M%S).bak"

cat > "$FILE" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>ZY Music Command — Live Demo Presentation</title>
<style>
:root{--bg:#07080d;--panel:#0d1018;--panel2:#111827;--gold:#ffd230;--purple:#a855f7;--teal:#14f195;--pink:#ff3d81;--text:#f8fafc;--muted:#9ca3af;--line:rgba(255,255,255,.1);--mono:"Courier New",monospace;--head:Arial Black,Impact,sans-serif}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 18% 0,rgba(168,85,247,.22),transparent 30%),radial-gradient(circle at 84% 10%,rgba(20,241,149,.14),transparent 28%),var(--bg);color:var(--text);font-family:Inter,Arial,sans-serif;overflow:hidden}
.slide{display:none;width:100vw;height:100vh;padding:52px 64px;position:relative}.slide.active{display:block}
.kicker{font-family:var(--mono);font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--teal);margin-bottom:14px}
h1{font-family:var(--head);font-size:64px;line-height:.94;margin:0 0 18px;letter-spacing:-.04em}h1 span,h2 span{color:var(--gold)}
h2{font-family:var(--head);font-size:42px;line-height:1;margin:0 0 18px}p{color:#cbd5e1;font-size:20px;line-height:1.55;max-width:850px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}.grid4{display:grid;grid-template-columns:repeat(4,1fr);gap:14px}
.card{border:1px solid var(--line);background:rgba(255,255,255,.04);border-radius:18px;padding:20px}.card.hot{border-color:rgba(20,241,149,.55);box-shadow:0 0 28px rgba(20,241,149,.1)}
.metric{font-family:var(--head);font-size:40px;color:var(--teal)}.label{font-family:var(--mono);font-size:10px;color:var(--muted);letter-spacing:.14em;text-transform:uppercase}
.flow{display:grid;grid-template-columns:repeat(5,1fr);gap:10px;margin-top:28px}.step{min-height:130px;border:1px solid rgba(20,241,149,.25);background:rgba(20,241,149,.045);border-radius:16px;padding:16px}.step b{font-family:var(--mono);color:var(--teal);font-size:11px}.step h3{margin:10px 0 8px;font-size:16px}.step p{font-size:13px;color:var(--muted)}
.nav{position:fixed;right:22px;top:50%;transform:translateY(-50%);z-index:99;display:grid;gap:8px}.nav button,.btn{border:1px solid var(--line);background:rgba(255,255,255,.06);color:var(--text);border-radius:999px;padding:11px 15px;font-weight:900;cursor:pointer}.btn.primary{background:var(--gold);border-color:var(--gold);color:#050505}.btn.purple{border-color:rgba(168,85,247,.55);color:#d8b4fe}
.footer{position:absolute;left:64px;bottom:28px;font-family:var(--mono);font-size:11px;color:var(--muted)}.count{position:fixed;left:22px;bottom:18px;font-family:var(--mono);color:var(--muted);z-index:100}
pre{white-space:pre-wrap;max-height:320px;overflow:auto;background:rgba(0,0,0,.28);border:1px solid var(--line);border-radius:14px;padding:16px;color:#d1d5db;font-size:13px;line-height:1.55}
.barwrap{height:8px;background:rgba(255,255,255,.08);border-radius:999px;overflow:hidden;margin-top:8px}.bar{height:100%;background:linear-gradient(90deg,var(--teal),var(--purple))}
.timeline{display:flex;gap:8px;align-items:flex-end;height:160px;border:1px solid var(--line);border-radius:18px;background:rgba(255,255,255,.035);padding:18px}.tbar{flex:1;border-radius:8px 8px 0 0;background:linear-gradient(180deg,var(--purple),var(--teal));min-height:10px;position:relative}.tbar span{position:absolute;bottom:-24px;left:50%;transform:translateX(-50%);font-family:var(--mono);font-size:10px;color:var(--muted)}
.demoBox{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:18px}textarea{width:100%;min-height:130px;background:#0b1020;color:var(--text);border:1px solid var(--line);border-radius:14px;padding:14px;font-size:15px}
@media(max-width:960px){.grid,.grid3,.grid4,.flow,.demoBox{grid-template-columns:1fr}h1{font-size:44px}.slide{padding:32px;overflow:auto}.nav{display:none}}
</style>
</head>
<body>

<div class="nav"><button onclick="prev()">↑</button><button onclick="next()">↓</button></div>
<div class="count" id="count"></div>

<section class="slide active">
  <div class="kicker">TSM Matter · Music Command Center</div>
  <h1>ZY Music Command<br><span>Live Product Demo</span></h1>
  <p>AI songwriting decision engine for artists, producers, and songwriters. Generate options, score directions, pick the strongest path, rerun, learn, and track hit trajectory.</p>
  <div style="display:flex;gap:12px;margin-top:28px;flex-wrap:wrap">
    <a class="btn primary" href="/html/music-command/index.html">Open App</a>
    <a class="btn purple" href="/html/music-command/marketing.html">Marketing Page</a>
    <button class="btn" onclick="refreshAll()">Refresh Live Data</button>
  </div>
  <div class="footer">Use ↑ / ↓ arrows to navigate</div>
</section>

<section class="slide">
  <div class="kicker">Problem</div>
  <h1>Creators don’t need more random lyrics.<br><span>They need decisions.</span></h1>
  <div class="grid">
    <div class="card"><h2>Old workflow</h2><p>Write → generate → guess → rewrite → abandon.</p></div>
    <div class="card hot"><h2>New workflow</h2><p>Generate → score → compare → select → rerun → learn.</p></div>
  </div>
</section>

<section class="slide">
  <div class="kicker">Live System State</div>
  <h1>Music Command is online.</h1>
  <div class="grid4">
    <div class="card"><div class="metric" id="mArtists">—</div><div class="label">Artists Online</div></div>
    <div class="card"><div class="metric" id="mDrops">—</div><div class="label">Releases Dropping</div></div>
    <div class="card"><div class="metric" id="mStreams">—</div><div class="label">Monthly Streams</div></div>
    <div class="card"><div class="metric" id="mPipe">—</div><div class="label">Pipeline Value</div></div>
  </div>
  <pre id="stateRaw">Loading /api/music/state...</pre>
</section>

<section class="slide">
  <div class="kicker">Multi-Agent Engine</div>
  <h1>ZAY → RIYA → DJ</h1>
  <div class="grid3">
    <div class="card hot"><h2>ZAY</h2><p>Cadence, bounce, flow, pocket.</p></div>
    <div class="card"><h2>RIYA</h2><p>Emotion, imagery, voice, vulnerability.</p></div>
    <div class="card"><h2>DJ</h2><p>Structure, hook placement, transitions.</p></div>
  </div>
</section>

<section class="slide">
  <div class="kicker">Live Agent Run</div>
  <h1>Run the engine during the pitch.</h1>
  <div class="demoBox">
    <div>
      <textarea id="demoDraft">Life surrounded by wrong but trying to stay right is a fight
Every day a battle every night a new light</textarea>
      <button class="btn primary" onclick="runLiveChain()" style="margin-top:12px">Run ZAY → RIYA → DJ</button>
    </div>
    <pre id="chainResult">Click Run to call /api/music/agent/chain</pre>
  </div>
</section>

<section class="slide">
  <div class="kicker">Scoring</div>
  <h1>Every version becomes measurable.</h1>
  <div class="grid4">
    <div class="card"><div class="label">Cadence</div><div class="metric" id="sCad">—</div><div class="barwrap"><div class="bar" id="bCad" style="width:0%"></div></div></div>
    <div class="card"><div class="label">Emotion</div><div class="metric" id="sEmo">—</div><div class="barwrap"><div class="bar" id="bEmo" style="width:0%"></div></div></div>
    <div class="card"><div class="label">Structure</div><div class="metric" id="sStr">—</div><div class="barwrap"><div class="bar" id="bStr" style="width:0%"></div></div></div>
    <div class="card hot"><div class="label">Overall</div><div class="metric" id="sOverall">—</div><div class="barwrap"><div class="bar" id="bOverall" style="width:0%"></div></div></div>
  </div>
</section>

<section class="slide">
  <div class="kicker">Evolution Timeline</div>
  <h1>Hit trajectory, not guesswork.</h1>
  <div class="timeline" id="timeline"><div style="color:var(--muted)">Loading /api/music/evolution...</div></div>
  <div class="grid" style="margin-top:36px">
    <div class="card hot"><div class="label">Release Decision</div><h2 id="decision">—</h2></div>
    <div class="card"><div class="label">Hit Potential</div><h2 id="hit">—</h2></div>
  </div>
</section>

<section class="slide">
  <div class="kicker">Artist DNA</div>
  <h1>The system learns the artist.</h1>
  <div class="grid">
    <div class="card"><h2>DNA Weights</h2><pre id="dnaWeights">Loading...</pre></div>
    <div class="card"><h2>Learned Songs</h2><pre id="learnedSongs">Loading...</pre></div>
  </div>
</section>

<section class="slide">
  <div class="kicker">Monetization</div>
  <h1>Free → Creator → Studio → Label</h1>
  <div class="grid4" id="plans"></div>
</section>

<section class="slide">
  <div class="kicker">Close</div>
  <h1>This is not a lyric generator.<br><span>It is a decision system for music.</span></h1>
  <p>For artists: better songs faster. For producers: faster sessions. For songwriters: clearer creative direction. For labels: catalog-scale decision intelligence.</p>
  <a class="btn primary" href="/html/music-command/index.html">Open Live App</a>
</section>

<script>
let idx=0; const slides=[...document.querySelectorAll('.slide')];
function show(n){idx=(n+slides.length)%slides.length;slides.forEach(s=>s.classList.remove('active'));slides[idx].classList.add('active');document.getElementById('count').textContent=(idx+1)+' / '+slides.length}
function next(){show(idx+1)} function prev(){show(idx-1)}
document.addEventListener('keydown',e=>{if(e.key==='ArrowDown'||e.key==='ArrowRight')next();if(e.key==='ArrowUp'||e.key==='ArrowLeft')prev()}); show(0);

async function safeJson(url, opts={}){
  const r=await fetch(url, opts);
  try{return await r.json()}catch(e){return {ok:false,error:'Non-JSON response'}}
}
function pct(v){return Math.round(Number(v||0)*100)}
function setScore(s){
  const map=[['Cad','cadence'],['Emo','emotion'],['Str','structure'],['Overall','overall']];
  map.forEach(([id,k])=>{
    const val=pct(s?.[k]);
    document.getElementById('s'+id).textContent=val?val+'%':'—';
    document.getElementById('b'+id).style.width=(val||0)+'%';
  });
}
async function loadState(){
  const data=await safeJson('/api/music/state');
  document.getElementById('stateRaw').textContent=JSON.stringify(data,null,2);
  const st=data.state||{};
  document.getElementById('mArtists').textContent=st.artistsOnline ?? '12';
  document.getElementById('mDrops').textContent=st.releasesDropping ?? '3';
  document.getElementById('mStreams').textContent=st.monthlyStreams ?? '84M';
  document.getElementById('mPipe').textContent=st.pipelineValue ? '$'+Number(st.pipelineValue).toLocaleString() : '$2.4M';
}
async function runLiveChain(){
  const draft=document.getElementById('demoDraft').value;
  const data=await safeJson('/api/music/agent/chain',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({draft,request:'live presentation demo'})});
  document.getElementById('chainResult').textContent=JSON.stringify(data.run||data,null,2);
  if(data.run?.score)setScore(data.run.score);
  await loadEvolution();
}
async function loadEvolution(){
  const data=await safeJson('/api/music/evolution');
  const tl=document.getElementById('timeline');
  const timeline=data.timeline||[];
  tl.innerHTML = timeline.length ? timeline.map(t=>`<div class="tbar" style="height:${Math.max(10,pct(t.overall))}%"><span>${pct(t.overall)}</span></div>`).join('') : '<div style="color:var(--muted)">No runs yet. Run the live agent chain first.</div>';
  document.getElementById('decision').textContent=data.decision||'—';
  document.getElementById('hit').textContent=data.hit?`${data.hit.percent}% · ${data.hit.label}`:'—';
  document.getElementById('dnaWeights').textContent=JSON.stringify(data.dna?.weights||{},null,2);
  document.getElementById('learnedSongs').textContent=JSON.stringify((data.dna?.learnedSongs||[]).slice(0,3),null,2);
  if(data.latest?.score)setScore(data.latest.score);
}
async function loadBilling(){
  const data=await safeJson('/api/music/billing/state');
  const tiers=data.billing?.tiers||{};
  document.getElementById('plans').innerHTML=Object.entries(tiers).map(([k,t])=>`
    <div class="card ${k==='tier2'?'hot':''}">
      <div class="label">${k}</div>
      <h2>${t.name}</h2>
      <div class="metric">$${t.price}</div>
      <p>${t.aiRuns} AI iterations<br>${t.sessions} projects<br>${t.exports?'Exports included':'Exports locked'}<br>${t.dna}</p>
    </div>`).join('');
}
async function refreshAll(){await loadState();await loadEvolution();await loadBilling()}
refreshAll();
</script>
</body>
</html>
HTML

git add "$FILE"
git commit -m "Add live interactive Music Command presentation" || true
git push origin main
fly deploy --local-only

echo "DONE: https://tsm-shell.fly.dev/html/music-command/presentation-live.html?v=live"
