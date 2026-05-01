#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

DST="html/honor-portal/index.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/honor_portal_fixed
cp -f "$DST" "backups/honor_portal_fixed/index.$STAMP.bak"

cat > "$DST" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>HonorHealth · Dee Command Center</title>

<style>
body{
  margin:0;
  background:#050b14;
  color:#d9fff2;
  font-family:Arial;
}
.wrap{max-width:1200px;margin:auto;padding:20px}
.btn{
  background:#0a1822;
  color:#fff;
  border:1px solid #00ffa3;
  padding:10px;
  margin:5px;
  cursor:pointer;
}
.section{
  margin-top:20px;
  padding:15px;
  border:1px solid rgba(0,255,163,.2);
}
</style>
</head>

<body>
<div class="wrap">

<h2>Dee Command Center</h2>

<div>
  <button class="btn" onclick="runAction('recovery')">Run Recovery</button>
  <button class="btn" onclick="runAction('payer')">Escalate Payer</button>
  <button class="btn" onclick="runAction('brief')">Executive Brief</button>
</div>

<div id="output" class="section">
Loading...
</div>

</div>

<script>
async function runAction(type){
  document.getElementById('output').innerHTML = "Running " + type + "...";

  try{
    const res = await fetch('/api/strategist/hc/dee-action',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({
        system:'HonorHealth',
        prompt:type
      })
    });

    const data = await res.json();

    document.getElementById('output').innerHTML =
      "<pre>"+JSON.stringify(data,null,2)+"</pre>";

  }catch(e){
    document.getElementById('output').innerHTML = "Error: "+e.message;
  }
}

window.onload = () => runAction('initial');
</script>

</body>
</html>
HTML

git add "$DST"
git commit -m "Fix broken HTML and restore working Dee page" || true
git push origin main || true
fly deploy
