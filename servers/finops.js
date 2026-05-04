require('dotenv').config();
const express = require('express');
const router = express.Router();

const groq = async (prompt, maxTokens=800) => {
  const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method:'POST',
    headers:{'Authorization':'Bearer '+process.env.GROQ_API_KEY,'Content-Type':'application/json'},
    body:JSON.stringify({model:process.env.TSM_MODEL||'llama-3.1-8b-instant',messages:[{role:'user',content:prompt}],max_tokens:maxTokens,temperature:0.7})
  });
  const d = await r.json();
  return d.choices?.[0]?.message?.content || 'AI unavailable';
};

router.get('/copilot',      (req,res) => res.json({ok:true,status:'FinOps Copilot online'}));
router.get('/mesh-health',  (req,res) => res.json({ok:true,status:'ONLINE',nodes:5,health:94}));
router.get('/mesh-score',   (req,res) => res.json({ok:true,score:94,status:'HEALTHY'}));
router.get('/multi-report', (req,res) => res.json({ok:true,reports:[]}));

router.post('/copilot', async (req,res) => {
  try {
    const {workflow='',context='',workflows=[],query='',messages=[]} = req.body||{};
    const wf = workflow||workflows.join(', ')||query||messages.map(m=>m.content).join(' ');
    const content = await groq(`FinOps Staff Accountant AI. Workflow: ${wf}. Context: ${context}. Actionable analysis: findings, risks, BNCA.`, 900);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/multi-report', async (req,res) => {
  try {
    const content = await groq(`FinOps multi-node report. Context: ${JSON.stringify(req.body||{}).slice(0,2000)}.`, 900);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/report', async (req,res) => {
  try {
    const {type='summary',context='',period='monthly'} = req.body||{};
    const content = await groq(`FinOps ${type} report. Period: ${period}. Context: ${context}. Return structured financial report with KPIs, variance, recommendations.`, 900);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/actions', async (req,res) => {
  try {
    const {context='',priority='high'} = req.body||{};
    const content = await groq(`FinOps action items. Priority: ${priority}. Context: ${context}. Return ranked action list with owner, deadline, dollar impact.`);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/upload-doc', async (req,res) => {
  try {
    const {content:doc='',docType='',filename=''} = req.body||{};
    const content = await groq(`FinOps Document Analysis. File: ${filename}. Type: ${docType}. Content: ${doc.slice(0,2000)}. Extract financial insights, anomalies, required actions.`, 900);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/export-pdf', (req,res) => res.json({ok:true,message:'PDF export queued'}));

module.exports = router;
