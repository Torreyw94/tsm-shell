module.exports = function(app){

  global.HC_TASK_QUEUE = global.HC_TASK_QUEUE || [];

  function buildOfficePayload(office){
    const officeName = office || "Scottsdale - Shea";

    const officeMap = {
      "Scottsdale - Shea": {
        denialRate: 12.4,
        authDelay: 56,
        queueDepth: 31,
        revenueAtRisk: 229850,
        recoverable72h: 78149,
        cashAcceleration14d: 109409,
        highestYieldLane: "Insurance",
        rootCause: [
          "Billing: denial 12.4% with lag 6d",
          "Insurance: auth backlog 27, delay 56h",
          "Operations: queue 31, backlog 18, staffing 86%"
        ],
        bestNextActions: [
          "Clear highest-value backlog first",
          "Escalate auth and documentation blockers older than 24–72 hours",
          "Align intake, billing, and scheduling handoffs for the next shift"
        ],
        ownerLanes: ["Operations", "Billing", "Insurance"],
        summary: "HonorHealth risk is concentrated in Scottsdale - Shea. Highest-yield lane is Insurance. Immediate focus: clear the highest-value backlog first.",
        confidence: 91
      },
      "Mesa Family Practice": {
        denialRate: 9.8,
        authDelay: 22,
        queueDepth: 18,
        revenueAtRisk: 182000,
        recoverable72h: 62000,
        cashAcceleration14d: 98000,
        highestYieldLane: "Operations",
        rootCause: [
          "Operations: queue pressure and staffing gaps",
          "Billing: follow-up lag on aging claims",
          "Insurance: moderate auth friction"
        ],
        bestNextActions: [
          "Stabilize staffing and reduce queue pressure",
          "Push aged claims through billing follow-up",
          "Triage auth blockers by payer priority"
        ],
        ownerLanes: ["Operations", "Billing"],
        summary: "Mesa pressure is operational first, then billing throughput. Immediate focus: stabilize staffing and reduce queue pressure.",
        confidence: 84
      }
    };

    const d = officeMap[officeName] || officeMap["Scottsdale - Shea"];
    return {
      office: officeName,
      denialRate: d.denialRate,
      authDelay: d.authDelay,
      queueDepth: d.queueDepth,
      revenueAtRisk: d.revenueAtRisk,
      recoverable72h: d.recoverable72h,
      cashAcceleration14d: d.cashAcceleration14d,
      highestYieldLane: d.highestYieldLane,
      rootCause: d.rootCause,
      bestNextActions: d.bestNextActions,
      ownerLanes: d.ownerLanes,
      summary: d.summary,
      confidence: d.confidence
    };
  }

  app.post('/api/hc/delegate', (req, res) => {
    const office = (req.body && req.body.office) || 'Scottsdale - Shea';
    const action = (req.body && req.body.action) || 'Execute BNCA';
    const ownerLane = (req.body && req.body.ownerLane) || 'Operations';
    const mode = (req.body && req.body.mode) || 'bnca';

    const task = {
      id: Date.now(),
      office,
      action,
      ownerLane,
      mode,
      status: 'assigned',
      createdAt: new Date().toISOString()
    };

    global.HC_TASK_QUEUE.unshift(task);
    global.HC_TASK_QUEUE = global.HC_TASK_QUEUE.slice(0, 25);

    return res.json({ ok: true, task, queue: global.HC_TASK_QUEUE });
  });

  app.get('/api/hc/tasks', (_req, res) => {
    return res.json({ ok: true, tasks: global.HC_TASK_QUEUE || [] });
  });

  app.post('/api/hc/bnca', (req, res) => {
    const office = (req.body && req.body.office) || 'Scottsdale - Shea';
    const mode = (req.body && req.body.mode) || 'bnca';
    const d = buildOfficePayload(office);

    const payload = {
      ok: true,
      office,
      mode,
      updatedAt: new Date().toISOString(),
      summary: d.summary,
      layer2: {
        revenueAtRisk: d.revenueAtRisk,
        recoverable72h: d.recoverable72h,
        cashAcceleration14d: d.cashAcceleration14d,
        highestYieldLane: d.highestYieldLane,
        rootCause: d.rootCause,
        bestNextActions: d.bestNextActions,
        ownerLanes: d.ownerLanes,
        confidence: d.confidence
      },
      actionBoard: {
        topPriorityNow: d.bestNextActions[0],
        strategistNarrative: d.summary
      },
      actionDetail: null
    };

    if (mode === 'payer') {
      payload.actionDetail = {
        title: 'Payer Intervention',
        steps: [
          'Pull all pending auth requests for ' + office + ' older than 24h',
          'Prioritize high-value auth blockers',
          'Escalate payer delays over 48h',
          'Route documentation blockers to billing and insurance immediately'
        ]
      };
    } else if (mode === 'recovery') {
      payload.actionDetail = {
        title: 'Recovery Actions',
        steps: d.bestNextActions
      };
    } else if (mode === 'brief') {
      payload.actionDetail = {
        title: 'Executive Brief',
        steps: [
          'Revenue at risk: $' + Number(d.revenueAtRisk).toLocaleString(),
          'Recoverable 72h: $' + Number(d.recoverable72h).toLocaleString(),
          'Top lane: ' + d.highestYieldLane,
          'Confidence: ' + d.confidence + '%'
        ]
      };
    } else if (mode === 'compare') {
      payload.actionDetail = {
        title: 'Compare Mode',
        steps: [
          office + ' vs best-performing office',
          'Top issue: ' + d.rootCause[0],
          'Primary action: ' + d.bestNextActions[0]
        ]
      };
    }

    return res.json(payload);
  });

};
