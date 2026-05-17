let idx=0,seconds=0,interval=null;
const steps=[...document.querySelectorAll('.step')];
const tabs=[...document.querySelectorAll('.tab')];
const nodes=[...document.querySelectorAll('.node')];

function show(i){
  idx=i;
  steps.forEach((s,n)=>s.classList.toggle('active',n===i));
  tabs.forEach((t,n)=>t.classList.toggle('active',n===i));
  nodes.forEach((n,x)=>n.classList.toggle('active',x===i));
}
tabs.forEach((t,i)=>t.onclick=()=>show(i));
nodes.forEach((n,i)=>n.onclick=()=>show(i));

document.getElementById('startBtn')?.addEventListener('click',()=>{
  if(interval) return;
  interval=setInterval(()=>{
    seconds++;
    document.getElementById('clock').textContent=
      String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');
  },1000);
});
document.getElementById('resetBtn')?.addEventListener('click',()=>{
  clearInterval(interval);interval=null;seconds=0;document.getElementById('clock').textContent='00:00';
});
document.getElementById('printBtn')?.addEventListener('click',()=>window.print());
show(0);
