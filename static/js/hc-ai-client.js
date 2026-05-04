window.runHCNodeAI = async function(node, message){
  try{
    const res = await fetch('/api/hc/node', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({ node, message })
    });

    return await res.json();
  }catch(e){
    return {
      bnca:{
        priority:"System fallback engaged",
        actions:[
          "Retry analysis",
          "Check connectivity",
          "Escalate system review"
        ],
        owner:"System",
        timeline:"Now",
        risk:"AI connection failure"
      }
    };
  }
};
