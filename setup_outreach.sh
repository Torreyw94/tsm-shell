#!/usr/bin/env bash
set -e

mkdir -p outreach
cd outreach

# leads file
echo "[]" > leads.json

# main script
cat > outreach.js <<'JS'
const fs = require('fs');
const fetch = require('node-fetch');

const API = 'https://tsm-shell.fly.dev';

function load(){
  return JSON.parse(fs.readFileSync('./leads.json'));
}

function save(data){
  fs.writeFileSync('./leads.json', JSON.stringify(data,null,2));
}

async function createDemo(name){
  const res = await fetch(API+'/api/music/demo/create',{
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify({client:name,hours:24})
  });
  return await res.json();
}

async function add(name, handle){
  const leads = load();
  const demo = await createDemo(name);

  const lead = {
    name,
    handle,
    link: API + demo.links.presentation,
    created: new Date().toISOString()
  };

  leads.push(lead);
  save(leads);

  console.log("\n✅ Lead Added:");
  console.log(lead);

  console.log("\n📩 SEND THIS:\n");
  console.log(`Quick question — how do you decide which version of a song is actually the best?

I built something that improves songs automatically.

Try this (expires soon):
${lead.link}`);
}

function list(){
  console.log(JSON.stringify(load(),null,2));
}

const cmd = process.argv[2];

if(cmd === 'add'){
  add(process.argv[3], process.argv[4]);
}
else if(cmd === 'list'){
  list();
}
else{
  console.log("node outreach.js add \"Name\" \"@handle\"");
}
JS

# install dep
npm init -y >/dev/null 2>&1
npm install node-fetch@2 >/dev/null 2>&1

echo "✅ Outreach system ready"
