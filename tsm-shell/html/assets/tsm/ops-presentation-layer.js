const OPS = {
  init(){
    const d = window.TSM_OPS;

    document.getElementById('title').textContent = d.title;
    document.getElementById('sub').textContent = d.subtitle;
    document.getElementById('price').textContent = d.systemPrice;

    document.getElementById('kpis').innerHTML =
      d.kpis.map(k=>`<div class="card"><b>${k.label}</b><div class="val">${k.value}</div><small>${k.caption}</small></div>`).join('');

    document.getElementById('nodes').innerHTML =
      d.nodes.map(n=>`<div class="card"><b>${n.name}</b><br>${n.status}<br><small>${n.role}</small></div>`).join('');

    document.getElementById('lanes').innerHTML =
      d.lanes.map(l=>`<div class="card"><b>${l.name}</b><div class="val">${l.metric}</div><small>${l.detail}</small></div>`).join('');

    document.getElementById('docs').innerHTML =
      d.docs.map(doc=>`<div class="card" onclick="OPS.select('${doc.title}')">
        <b>${doc.title}</b><br>
        <small>${doc.subtitle}</small>
      </div>`).join('');

    document.getElementById('actions').innerHTML =
      d.actions.map(a=>`<button onclick="OPS.run('${a.title}')">${a.button}</button>`).join('');

    document.getElementById('outcomeLine').textContent = d.defaultOutcome;
    document.getElementById('timeSaved').textContent = d.timeSaved;
  },

  select(title){
    const doc = window.TSM_OPS.docs.find(d=>d.title===title);
    document.getElementById('docOut').textContent = doc.sample;
    document.getElementById('coach').textContent = doc.coach;
  },

  run(title){
    const a = window.TSM_OPS.actions.find(x=>x.title===title);
    document.getElementById('liveOut').textContent =
      `${a.title}\n\n${a.lines.join("\n")}\n\nBNCA:\n${a.bnca}`;
  },

  runDoc(){
    document.getElementById('docOut').textContent = "Running selected healthcare workflow...";
  },

  runAll(){
    document.getElementById('docOut').textContent = window.TSM_OPS.allBnca;
  },

  pushMain(){
    window.open('/html/healthcare-main-strategist/index.html','_blank');
  },

  exportReport(){
    alert("PDF export ready (stub)");
  }
};

window.addEventListener('DOMContentLoaded', OPS.init);
