'use strict';
/**
 * wip-routes.js
 * Mount with:  require('./wip-routes')(app);
 * Handles BOTH /api/wip/:suite/... AND /wip/:suite/...
 */
const {constructionWIPRecon,healthcareWIPRecon,insuranceAuditRecon,finopsAccrualRecon} = require('./wip-handlers');

const HANDLERS = {
  construction: constructionWIPRecon,
  healthcare:   healthcareWIPRecon,
  insurance:    insuranceAuditRecon,
  finops:       finopsAccrualRecon,
};

function handle(req, res, fn) {
  fn(req.body || {})
    .then(r => res.json(r))
    .catch(e => { console.error(e); res.status(500).json({ok:false,error:e.message}); });
}

module.exports = function mountWIPRoutes(app) {
  // Explicit named routes — both prefixes
  const pairs = [
    ['/api/wip/construction/recon',    'construction'],
    ['/wip/construction/recon',        'construction'],
    ['/api/wip/healthcare/recon',      'healthcare'],
    ['/wip/healthcare/recon',          'healthcare'],
    ['/api/wip/insurance/audit-recon', 'insurance'],
    ['/wip/insurance/audit-recon',     'insurance'],
    ['/api/wip/finops/accrual-recon',  'finops'],
    ['/wip/finops/accrual-recon',      'finops'],
  ];
  pairs.forEach(([path, suite]) => {
    app.post(path, (req, res) => handle(req, res, HANDLERS[suite]));
  });

  // Generic catch-all — handles /api/wip/:suite/recon AND /wip/:suite/recon
  ['get','post'].forEach(method => {
    ['/api/wip/:suite/:action', '/wip/:suite/:action'].forEach(path => {
      app[method](path, (req, res) => {
        const h = HANDLERS[req.params.suite];
        if (!h) return res.status(404).json({ok:false,error:`No handler for suite: ${req.params.suite}`,available:Object.keys(HANDLERS)});
        handle(req, res, h);
      });
    });
  });

  // Health check
  app.get('/api/health', (_,res) => res.json({ok:true,ts:new Date().toISOString(),routes:Object.keys(HANDLERS)}));
  app.get('/health',     (_,res) => res.json({ok:true,ts:new Date().toISOString(),routes:Object.keys(HANDLERS)}));

  console.log('[WIP] Routes mounted: construction, healthcare, insurance, finops');
  console.log('[WIP] Prefixes: /api/wip/* and /wip/*');
};
