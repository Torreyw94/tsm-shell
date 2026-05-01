#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/outreach_tracking
cp -f outreach/outreach.js "backups/outreach_tracking/outreach.$STAMP.js"
cp -f outreach/leads.json "backups/outreach_tracking/leads.$STAMP.json"

cat > outreach/outreach.js <<'JS'
const fs = require('fs');
const fetch = require('node-fetch');

const API = 'https://tsm-shell.fly.dev';
const LEADS = __dirname + '/leads.json';

function load(){
  if(!fs.existsSync(LEADS)) fs.writeFileSync(LEADS, '[]');
  return JSON.parse(fs.readFileSync(LEADS, 'utf8') || '[]');
}

function save(data){
  fs.writeFileSync(LEADS, JSON.stringify(data,null,2));
}

async function createDemo(name){
  const res = await fetch(API+'/api/music/demo/create',{
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify({client:name,hours:24})
  });
  return await res.json();
}

async function add(name, handle, type='artist'){
  const leads = load();
  const demo = await createDemo(name);

  const lead = {
    name,
    handle,
    type,
    link: API + demo.links.presentation,
    app: API + demo.links.app,
    token: demo.demo.token,
    created: new Date().toISOString(),
    status: 'new',
    score: 0,
    lastActivity: null,
    suggestedFollowUp: null
  };

  leads.push(lead);
  save(leads);

  console.log("\n✅ Lead Added:");
  console.log(lead);

  console.log("\n📩 SEND THIS:\n");
  console.log(messageFor(lead));
}

function messageFor(lead){
  if(lead.type === 'producer'){
    return `You probably see a lot of rough drafts from artists.

This takes one draft, runs multiple versions, scores them, and improves it until the strongest version emerges.

Private demo link, expires soon:
${lead.link}`;
  }

  return `Quick question — how do you decide which version of a song is actually the best?

I built something that improves songs automatically — not just generates them.

Try this private demo, expires soon:
${lead.link}

Paste your own lyrics and hit run.`;
}

async function dealRoom(){
  const res = await fetch(API+'/api/music/demo/deal-room');
  return await res.json();
}

function scoreLead(tokenData, usageData){
  const views = tokenData.views || 0;
  const hits = usageData?.hits || 0;
  const actions = usageData?.actions || {};
  let score = 0;

  score += views * 20;
  score += hits * 5;

  Object.keys(actions).forEach(k => {
    if(k.includes('agent') || k.includes('revision')) score += actions[k] * 15;
    if(k.includes('demo_view')) score += actions[k] * 10;
    if(k.includes('billing') || k.includes('upgrade')) score += actions[k] * 25;
  });

  if(tokenData.locked) score += 25;

  return Math.min(score, 100);
}

function followUpFor(lead, tokenData, usageData, score){
  const views = tokenData.views || 0;
  const hits = usageData?.hits || 0;

  if(tokenData.locked){
    return `Looks like you hit the demo limit.

That usually means it’s worth going deeper — want me to unlock a higher version for you?`;
  }

  if(score >= 70){
    return `Looks like you really got into the demo.

If you were using this regularly, would it help more with:
A) finishing songs faster
B) improving quality
C) both`;
  }

  if(views >= 2){
    return `That’s usually where it clicks.

Did the second run feel different than normal AI tools?`;
  }

  if(views >= 1 || hits >= 1){
    return `Curious — what did you think after running it once?

Most people notice the difference after the second iteration.`;
  }

  return `Did you get a chance to try the demo?

It only takes one lyric paste to see the difference.`;
}

async function sync(){
  const leads = load();
  const room = await dealRoom();
  const tokens = room.tokens || [];
  const usage = room.usage || {};

  leads.forEach(lead => {
    const t = tokens.find(x => x.token === lead.token);
    if(!t) return;

    const u = usage[lead.token];
    const score = scoreLead(t, u);

    lead.views = t.views || 0;
    lead.locked = !!t.locked;
    lead.lockReason = t.lockReason || null;
    lead.events = t.events || [];
    lead.usage = u || null;
    lead.score = score;
    lead.lastActivity = u?.lastSeen || (t.events?.[0]?.createdAt) || lead.lastActivity;
    lead.status =
      t.locked ? 'locked' :
      score >= 70 ? 'hot' :
      score >= 35 ? 'warm' :
      lead.views > 0 ? 'opened' :
      lead.status || 'new';

    lead.suggestedFollowUp = followUpFor(lead, t, u, score);
  });

  save(leads);

  console.log('\n✅ Synced lead activity\n');
  dashboard();
}

function dashboard(){
  const leads = load().sort((a,b)=>(b.score||0)-(a.score||0));

  console.log('ZY MUSIC OUTREACH DASHBOARD');
  console.log('===========================\n');

  leads.forEach((l,i)=>{
    const badge = (l.score||0) >= 70 ? '🔥 HOT' : (l.score||0) >= 35 ? '⚡ WARM' : l.views ? '👀 OPENED' : '—';
    console.log(`${i+1}. ${badge} ${l.name} ${l.handle||''}`);
    console.log(`   Status: ${l.status || 'new'} · Score: ${l.score || 0} · Views: ${l.views || 0} · Locked: ${!!l.locked}`);
    console.log(`   Link: ${l.link}`);
    console.log(`   Follow-up: ${l.suggestedFollowUp || 'Send initial DM'}`);
    console.log('');
  });
}

function followups(){
  const leads = load().sort((a,b)=>(b.score||0)-(a.score||0));
  leads.forEach(l=>{
    console.log(`\nFOLLOW UP → ${l.name} ${l.handle||''}`);
    console.log(l.suggestedFollowUp || 'Did you get a chance to try the demo?');
  });
}

function list(){
  console.log(JSON.stringify(load(), null, 2));
}

const cmd = process.argv[2];

(async()=>{
  if(cmd === 'add') await add(process.argv[3], process.argv[4], process.argv[5] || 'artist');
  else if(cmd === 'list') list();
  else if(cmd === 'sync') await sync();
  else if(cmd === 'dashboard') dashboard();
  else if(cmd === 'followups') followups();
  else {
    console.log(`
Commands:
node outreach/outreach.js add "Artist Name" "@handle" artist
node outreach/outreach.js add "Producer Name" "@handle" producer
node outreach/outreach.js sync
node outreach/outreach.js dashboard
node outreach/outreach.js followups
node outreach/outreach.js list
`);
  }
})();
JS

git add outreach/outreach.js outreach/leads.json
git commit -m "Add ZY Music outreach open tracking and follow-up scoring" || true

echo
echo "✅ Outreach tracking upgraded."
echo
echo "Use:"
echo "node outreach/outreach.js sync"
echo "node outreach/outreach.js dashboard"
echo "node outreach/outreach.js followups"
