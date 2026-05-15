#!/usr/bin/env python3
"""
Run from /workspaces/tsm-shell:  python3 patch-finops-wip.py
"""
from pathlib import Path

HTML   = Path('/workspaces/tsm-shell/html')
TARGET = HTML / 'wip-dashboard.html'
SERVER = Path('/workspaces/tsm-shell/server.js')

# ── 1. FIX SERVER STREAM ROUTE ────────────────────────────────────
ssrc = SERVER.read_text()
stream_route = """
// ── Groq streaming proxy ─────────────────────────────────────────
app.post('/api/groq/stream', express.json({limit:'2mb'}), async (req, res) => {
  const key = process.env.GROQ_API_KEY;
  if (!key) return res.status(503).json({error:'No API key configured'});
  try {
    const upstream = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method:'POST',
      headers:{'Authorization':'Bearer '+key,'Content-Type':'application/json'},
      body: JSON.stringify({...req.body, stream:true})
    });
    res.setHeader('Content-Type','text/event-stream');
    res.setHeader('Cache-Control','no-cache');
    upstream.body.pipeTo(new WritableStream({
      write(chunk){ res.write(chunk); },
      close(){ res.end(); }
    }));
  } catch(e){ res.status(500).json({error:e.message}); }
});
"""
if '/api/groq/stream' not in ssrc:
    # Place before app.listen
    if 'app.listen' in ssrc:
        ssrc = ssrc.replace('app.listen', stream_route + '\napp.listen', 1)
        Server.write_text(ssrc)
        print('✔ /api/groq/stream added')
else:
    # Route exists but might be after catch-all — move it before app.listen
    ssrc = ssrc.replace(stream_route.strip(), '')
    ssrc = ssrc.replace('app.listen', stream_route + '\napp.listen', 1)
    SERVER.write_text(ssrc)
    print('✔ /api/groq/stream repositioned before app.listen')

# ── 2. INJECT FINOPS SECTOR INTO WIP DASHBOARD ───────────────────
src = TARGET.read_text()

# A. Add sector button
old_btn = '<button class="sector-btn" id="btn-insurance" onclick="setSector(\'insurance\')">📋 INSURANCE</button>'
new_btn = '''<button class="sector-btn" id="btn-insurance" onclick="setSector(\'insurance\')">📋 INSURANCE</button>
    <button class="sector-btn" id="btn-finops" onclick="setSector(\'finops\')">💰 FINOPS</button>'''
if 'btn-finops' not in src:
    src = src.replace(old_btn, new_btn)
    print('✔ FinOps sector button added')

# B. Add body class
old_body = "body.sector-insurance{--s-color:#a855f7}"
new_body = """body.sector-insurance{--s-color:#a855f7}
body.sector-finops{--s-color:#f5c842}"""
if 'sector-finops' not in src:
    src = src.replace(old_body, new_body)
    print('✔ FinOps CSS class added')

# C. Add FinOps sector data + setSector handler
finops_data = """
  finops: {
    label: 'FinOps · Financial Command',
    bodyClass: 'sector-finops',
    color: '#f5c842',
    kpis: [
      { label:'AP AGING OUTSTANDING', value:'$312K', sub:'12 active invoices', delta:'3 credit hold vendors', cls:'delta-warn' },
      { label:'AR OUTSTANDING', value:'$198.6K', sub:'DSO: 52 days', delta:'↑ 17d over 35d target', cls:'delta-down' },
      { label:'MONTH-END CLOSE', value:'70%', sub:'May 10 deadline', delta:'Payroll blocked — HR', cls:'delta-warn' },
      { label:'CASH POSITION', value:'-$48K', sub:'bank variance open', delta:'⚠ Reconcile now', cls:'delta-down' },
      { label:'COMPLIANCE FLAGS', value:'4', sub:'missing approvals', delta:'6 QB access gaps', cls:'delta-down' },
      { label:'1099 / TAX RISK', value:'3', sub:'W-9s missing', delta:'2 at $600 threshold', cls:'delta-warn' },
    ],
    tableHeaders: ['AP/AR / ENTITY', '% RESOLVED', 'AMOUNT', 'COLLECTED / PAID', 'VARIANCE', 'STATUS'],
    tableRows: [
      ['Westside Holdings · AR', 15, '$18.4K', '$0', '-$18.4K', 'bad'],
      ['Acme Supply · AP', 5, '$14.2K', '$0', 'Credit hold', 'bad'],
      ['Delta Logistics · AR Dispute', 40, '$12.2K', '$0', 'Disputed', 'warn'],
      ['Bank Recon · $48K variance', 20, '$48K', '$0', '-$48K open', 'bad'],
      ['TechParts · AP', 60, '$5.8K', '$3.5K', '-$2.3K pending', 'warn'],
      ['Sunrise Group · AR', 80, '$8.6K', '$0', 'Promise May 10', 'warn'],
    ],
    alerts: [
      { sev:'CRIT', cls:'sev-crit', text:'<strong>Bank Recon $48K variance:</strong> 2 deposits in transit over 30 days. 1 check outstanding since January. Clear before month-end close or close will fail sign-off.' },
      { sev:'HIGH', cls:'sev-high', text:'<strong>Westside Holdings $18.4K — 97 days:</strong> 3 failed contact attempts. Initiate formal collections referral today. AR Manager action required by 9:30 AM.' },
      { sev:'HIGH', cls:'sev-high', text:'<strong>Month-End Close 70% — Payroll Blocked:</strong> HR has not submitted April payroll data. Close deadline May 10 at risk. Escalate to HR manager immediately.' },
      { sev:'MED', cls:'sev-med', text:'<strong>Compliance Shield — 4 Missing Approvals:</strong> 4 transactions without approvals. $1,970 Field Ops expense over policy limit — VP sign-off required. Zero Trust: 2 QB roles flagged for revocation.' },
    ],
    entities: [
      { id:'RECON-001', name:'Bank Variance $48K', meta:'20% resolved · $48K exposure · Risk: CRIT', risk:'92', riskCls:'cell-bad' },
      { id:'AR-WEST', name:'Westside Holdings AR', meta:'15% · $18.4K · 97 days · Risk: CRIT', risk:'88', riskCls:'cell-bad' },
      { id:'CLOSE-MAY', name:'Month-End Close', meta:'70% complete · May 10 deadline · Risk: HIGH', risk:'75', riskCls:'cell-bad' },
      { id:'AR-DELTA', name:'Delta Logistics Dispute', meta:'40% · $12.2K disputed · Risk: MED', risk:'50', riskCls:'cell-warn' },
      { id:'TAX-1099', name:'1099 / W-9 Readiness', meta:'3 W-9s missing · 2 threshold alerts · Risk: MED', risk:'44', riskCls:'cell-warn' },
    ],
    actions: ['Run Controller Action Plan — BNCA Report', 'Escalate Westside Holdings to Collections', 'Resolve Bank Variance — Trace Deposits', 'Submit Payroll Chase to HR', 'Push 4 Approval Flags to Controller', 'Generate 1099 Threshold Alert Report'],
    narrativePrompt: (e) => `You are the TSM FinOps Controller Strategist. Analyze this financial position: ${e.name} (${e.id}). Status: ${e.meta}. Produce a CFO-ready executive narrative covering: (1) financial position summary with dollar amounts, (2) risk assessment and compliance exposure, (3) 3 immediate controller actions with owners and deadlines, (4) month-end close impact and 30-day cash outlook. Be specific with amounts. Under 250 words.`,
  },"""

chart_data_finops = """
  finops: {
    B: {
      labels: ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct'],
      actual:  [0, 180, 420, 810, 1240, null, null, null, null, null],
      forecast:[0, 200, 480, 890, 1350, 1680, 1920, 2100, 2250, 2380],
      budget:  [0, 220, 500, 920, 1400, 1750, 2000, 2180, 2330, 2450],
      insight: '<strong>AP/AR resolution trending $110K below forecast.</strong> Westside Holdings and bank variance driving gap. Resolve both by May 10 to hit close target.',
    },
    C: {
      labels: ['Q1','Q2','Q3 Est','Q4 Est'],
      orig:    [95, 95, 95, 95],
      current: [95, 88, 82, 78],
      insight: '<strong>Collection rate declining:</strong> 95% → 78% projected. Primary drivers: AR dispute (Delta Logistics), 97-day aging (Westside). Controller Action Plan remediation targets 90%+ by Q3.',
    },
    D: {
      labels: ['May','Jun','Jul','Aug','Sep','Oct'],
      billings:[680, 820, 590, 940, 870, 790],
      costs:   [720, 760, 540, 880, 800, 720],
      net:     [-40, 60, 50, 60, 70, 70],
      insight: '<strong>Cash tight in May</strong> — AP batch + unresolved bank variance. Positive position June onward if Westside collected and bank recon cleared.',
    },
    E: {
      job: 'RECON-001 · Bank Variance $48K',
      tiles: [
        {label:'VARIANCE OPEN', value:'$48K', sub:'bank reconciliation', color:'#ff4455'},
        {label:'DEPOSITS IN TRANSIT', value:'2', sub:'over 30 days old', color:'#ff4455'},
        {label:'OUTSTANDING CHECK', value:'Jan', sub:'since January', color:'#ff4455'},
        {label:'CLOSE IMPACT', value:'HIGH', sub:'will block sign-off', color:'#ff4455'},
        {label:'DAYS OPEN', value:'47d', sub:'target: cleared by close', color:'#ffb300'},
        {label:'RISK LEVEL', value:'CRIT', sub:'risk score: 92', color:'#ff4455', pill:'risk-high'},
      ],
      stability: 'CRITICAL',
      insight: '<strong>Bank recon must clear before May 10</strong>: $48K variance blocks close sign-off. Assign staff accountant to trace both deposits in transit today.',
    },
    F: {
      jobs: [
        {id:'RECON-001', name:'Bank Variance', stat:'$48K unresolved', cls:'hm-red', pct:'20%'},
        {id:'AR-WEST', name:'Westside AR', stat:'$18.4K 97d', cls:'hm-red', pct:'15%'},
        {id:'CLOSE-MAY', name:'Month-End Close', stat:'70% — blocked', cls:'hm-yellow', pct:'70%'},
        {id:'AR-DELTA', name:'Delta Dispute', stat:'$12.2K disputed', cls:'hm-yellow', pct:'40%'},
        {id:'TAX-1099', name:'1099 Readiness', stat:'3 W-9s missing', cls:'hm-yellow', pct:'55%'},
      ],
      insight: '<strong>Portfolio: 2 critical / 3 yellow / 0 green.</strong> Month-end close at risk — bank variance and payroll blockage must resolve by May 10.',
    },
  },"""

# Inject FinOps into SECTORS object
old_sectors_end = "  insurance: {"
if 'finops:' not in src:
    src = src.replace(old_sectors_end, finops_data + '\n  insurance: {')
    print('✔ FinOps sector data injected into SECTORS')

# Inject FinOps into CHART_DATA object
old_chart_end = "  insurance: {\n    B: {"
if "finops: {\n    B:" not in src:
    src = src.replace(old_chart_end, chart_data_finops + '\n  insurance: {\n    B: {')
    print('✔ FinOps chart data injected into CHART_DATA')

# Inject FinOps into CHART_COLORS
old_colors_end = "  insurance:    { primary:'#a855f7', accent:'#00e5ff', neg:'#ff4455' },"
new_colors = """  insurance:    { primary:'#a855f7', accent:'#00e5ff', neg:'#ff4455' },
  finops:       { primary:'#f5c842', accent:'#00e5ff', neg:'#ff4455' },"""
if "finops:" not in src.split('CHART_COLORS')[1][:200] if 'CHART_COLORS' in src else True:
    src = src.replace(old_colors_end, new_colors)
    print('✔ FinOps chart colors added')

# Fix setSector to handle finops body class
old_sector_switch = "['construction','healthcare','insurance'].forEach(k => {"
new_sector_switch = "['construction','healthcare','insurance','finops'].forEach(k => {"
src = src.replace(old_sector_switch, new_sector_switch)

TARGET.write_text(src)
print('✔ wip-dashboard.html updated with FinOps sector')
print('\nRun: fly deploy')
