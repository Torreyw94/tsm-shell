#!/usr/bin/env node
// apply-finops-actions.js
// Usage: node apply-finops-actions.js [path/to/server.js]
// Default target: ./server.js

const fs = require('fs');
const path = require('path');

const target = process.argv[2] || path.join(__dirname, 'server.js');

if (!fs.existsSync(target)) {
  console.error(`❌  File not found: ${target}`);
  process.exit(1);
}

const ANCHOR = `app.get('/api/finops/docs', (req,res)=>{`;

const NEW_ROUTE = `
app.get('/api/finops/actions', (req, res) => {
  const memory = global.__TSM_STRATEGIST_MEMORY__?.finops || null;

  const actions = [
    {
      id: 'ap-vendor-invoice',
      lane: 'AP_VENDOR_INVOICE',
      label: 'Validate AP Vendor Invoices',
      count: 12,
      priority: 'HIGH'
    },
    {
      id: 'bank-reconciliation',
      lane: 'BANK_RECONCILIATION',
      label: 'Reconcile Bank Items',
      count: 3,
      priority: 'HIGH'
    },
    {
      id: 'month-end-close',
      lane: 'MONTH_END_CLOSE',
      label: 'Month-End Close Checklist',
      score: 84,
      priority: 'MEDIUM'
    },
    {
      id: '1099-tracker',
      lane: '1099_TRACKER',
      label: '1099 / W-9 Vendor Review',
      count: 7,
      priority: 'MEDIUM'
    },
    {
      id: 'executive-reporting',
      lane: 'EXECUTIVE_REPORTING',
      label: 'Executive Reporting Package',
      status: 'READY',
      priority: 'LOW'
    }
  ];

  res.json({ ok: true, actions, memory });
});

`;

let src = fs.readFileSync(target, 'utf8');

if (src.includes(`app.get('/api/finops/actions'`)) {
  console.log('⚠️  /api/finops/actions route already exists in file. No changes made.');
  process.exit(0);
}

if (!src.includes(ANCHOR)) {
  console.error(`❌  Could not find anchor line in ${target}:`);
  console.error(`    "${ANCHOR}"`);
  console.error('    Make sure the file is the correct server.js.');
  process.exit(1);
}

// Back up original
const backup = target + '.bak';
fs.writeFileSync(backup, src);
console.log(`✅  Backup saved → ${backup}`);

// Inject before the anchor
src = src.replace(ANCHOR, NEW_ROUTE + ANCHOR);
fs.writeFileSync(target, src);

console.log(`✅  Route injected into ${target}`);
console.log('');
console.log('Next steps:');
console.log('  1. Review the change:  git diff server.js');
console.log('  2. Deploy:             fly deploy');
console.log('  3. Verify:             curl https://tsm-shell.fly.dev/api/finops/actions');
