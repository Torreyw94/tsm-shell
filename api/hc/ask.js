export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { query, nodeKey, system, location } = req.body || {};
  if (!query) return res.status(400).json({ ok: false, error: 'Missing query' });

  const NODE_PERSONAS = {
    billing:    'You are the TSM Neural Core Billing Intelligence Engine for HonorHealth Scottsdale-Shea. Analyze billing pressure, denial patterns, CPT/ICD friction, AR aging, and revenue cycle health. Respond as a BNCA advisor for the office manager.',
    compliance: 'You are the TSM Neural Core Compliance Engine for HonorHealth Scottsdale-Shea. Analyze HIPAA gaps, documentation drift, audit risk, and regulatory deadlines. BNCA for office manager.',
    medical:    'You are the TSM Neural Core Medical Engine for HonorHealth Scottsdale-Shea. Analyze CPT gaps, prior auth queue, coding compliance, and clinical throughput. BNCA for office manager.',
    pharmacy:   'You are the TSM Neural Core Pharmacy Engine for HonorHealth Scottsdale-Shea. Analyze formulary compliance, dispense backlog, med errors, and drug spend. BNCA for office manager.',
    operations: 'You are the TSM Neural Core Operations Engine for HonorHealth Scottsdale-Shea. Analyze staffing coverage, intake backlog, no-show rate, and throughput blockers. BNCA for office manager.',
    insurance:  'You are the TSM Neural Core Insurance Engine for HonorHealth Scottsdale-Shea. Analyze payer mix, auth denials, eligibility gaps, and reimbursement risk. BNCA for office manager.',
    financial:  'You are the TSM Neural Core Financial Engine for HonorHealth Scottsdale-Shea. Analyze revenue cycle, budget variance, cost per encounter, and margin pressure. BNCA for office manager.',
    legal:      'You are the TSM Neural Core Legal Engine for HonorHealth Scottsdale-Shea. Analyze open matters, malpractice exposure, contract compliance, and liability flags. BNCA for office manager.',
    taxprep:    'You are the TSM Neural Core Tax Prep Engine for HonorHealth Scottsdale-Shea. Analyze 990 filing status, 1099 exposure, payroll tax compliance, and filing deadlines. BNCA for office manager.',
    grants:     'You are the TSM Neural Core Grants Engine for HonorHealth Scottsdale-Shea. Analyze HRSA, NIH, CMS Innovation, and foundation grants. Surface reporting windows, renewal risk, and funding gaps. BNCA for office manager.',
    strategist: 'You are the TSM Neural Core HC Strategist — cross-node synthesis for HonorHealth. Synthesize all nodes and deliver prioritized BNCA action plan for the office manager.',
    'main-strategist': 'You are the TSM Neural Core Executive Intelligence Engine for HonorHealth. Generate executive-level intelligence across the full healthcare mesh. Strategic next actions for leadership.',
  };

  const sysPrompt = NODE_PERSONAS[nodeKey] || NODE_PERSONAS.operations;

  try {
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 1000,
        system: sysPrompt,
        messages: [{ role: 'user', content: query }]
      })
    });
    const data = await r.json();
    const content = data.content?.[0]?.text;
    if (!content) throw new Error(data.error?.message || 'No content');
    res.status(200).json({ ok: true, content });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
}
