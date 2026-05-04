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

const hcPrompt = (ctx, q) => `Healthcare AI for HonorHealth Scottsdale. Context: ${ctx}. Query: ${q}. Be concise and actionable.`;

// Core ask + query (alias)
router.post('/ask',   async (req,res) => {
  try {
    const {query='',nodeKey='general',messages=[]} = req.body||{};
    const q = query || messages.map(m=>m.content).join(' ');
    const content = await groq(hcPrompt(`Node: ${nodeKey}`, q));
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/query', async (req,res) => {
  try {
    const {query='',message='',messages=[],nodeKey='general'} = req.body||{};
    const q = query||message||messages.map(m=>m.content).join(' ');
    const content = await groq(hcPrompt(`Node: ${nodeKey}`, q));
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});

// Nodes
router.get('/nodes', (req,res) => res.json({ok:true,nodes:['operations','billing','medical','pharmacy','financial','legal','vendors','compliance','tax-prep','grants','insurance']}));
router.post('/nodes/:node', async (req,res) => {
  try {
    const {node} = req.params;
    const bnca = await groq(`Analyze HC node: ${node} for HonorHealth. Payload: ${JSON.stringify(req.body||{}).slice(0,400)}. BNCA: top issue, actions, owner lane.`);
    res.json({ok:true,node,result:{node,status:'READY',bnca,confidence:92},ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/node', async (req,res) => {
  try {
    const {node='general',query=''} = req.body||{};
    const content = await groq(`HC node ${node} analysis. Query: ${query}. Actionable BNCA response.`);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});

// Layer 2
router.post('/layer2', async (req,res) => {
  try {
    const {query='',context='',messages=[]} = req.body||{};
    const q = query||messages.map(m=>m.content).join(' ');
    const content = await groq(`HonorHealth Layer 2 deep analysis. Context: ${context}. Query: ${q}. Provide mesh intelligence: cross-node patterns, risk signals, revenue impact, 30/60/90 actions.`, 1000);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});

// Tasks / Delegate
router.post('/tasks', async (req,res) => {
  try {
    const {query='',context=''} = req.body||{};
    const content = await groq(`HC Task Manager for HonorHealth. Context: ${context}. Query: ${query}. Return prioritized task list with owner, deadline, priority.`);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/delegate', async (req,res) => {
  try {
    const {task='',to='',context=''} = req.body||{};
    const content = await groq(`HC Delegation for HonorHealth. Task: ${task}. Delegate to: ${to}. Context: ${context}. Return delegation brief with accountability steps.`);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});

// Brief / Strategist / CFO
router.post('/brief', async (req,res) => {
  try {
    const {context='',scope='daily'} = req.body||{};
    const content = await groq(`HonorHealth ${scope} intelligence brief. Context: ${context}. Return: top 3 priorities, key metrics, risks, actions.`, 900);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/strategist', async (req,res) => {
  try {
    const {query='',context=''} = req.body||{};
    const content = await groq(`HonorHealth HC Strategist. Context: ${context}. Query: ${query}. Strategic recommendations with ROI and timeline.`, 900);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/cfo-report', async (req,res) => {
  try {
    const {context='',period='monthly'} = req.body||{};
    const content = await groq(`HonorHealth CFO Report. Period: ${period}. Context: ${context}. Return: revenue metrics, cost analysis, variance, recommendations.`, 1000);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});
router.post('/doc-analysis', async (req,res) => {
  try {
    const {content:doc='',docType='',query=''} = req.body||{};
    const content = await groq(`HC Document Analysis. Type: ${docType}. Query: ${query}. Document: ${doc.slice(0,2000)}. Extract key findings, risks, required actions.`, 900);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});

// BNCA
router.post('/bnca', async (req,res) => {
  try {
    const content = await groq(`HC Command Center BNCA for HonorHealth. Context: ${JSON.stringify(req.body||{}).slice(0,2000)}. Return: top issue, metrics, why it matters, best next action, owner lanes, confidence.`, 900);
    res.json({ok:true,content,reply:content,ts:new Date().toISOString()});
  } catch(e){res.status(500).json({ok:false,error:e.message});}
});

// Reports
router.get('/reports',  (req,res) => res.json({ok:true,reports:[]}));
router.post('/reports', (req,res) => {
  const {title='Report',company='HonorHealth',summary=''} = req.body||{};
  res.json({ok:true,report:{id:'r'+Date.now(),title,company,summary,createdAt:new Date().toISOString()}});
});

module.exports = router;
