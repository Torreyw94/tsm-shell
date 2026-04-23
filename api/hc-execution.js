module.exports = function(app){

  global.HC_TASK_QUEUE = global.HC_TASK_QUEUE || [];

  app.post('/api/hc/delegate', (req, res) => {
    const { office, action, ownerLane } = req.body || {};

    if (!office) {
      return res.status(400).json({ ok: false, error: "Missing office" });
    }

    const task = {
      id: Date.now(),
      office,
      action: action || "Execute BNCA",
      ownerLane: ownerLane || "Operations",
      status: "assigned",
      createdAt: new Date().toISOString()
    };

    global.HC_TASK_QUEUE.push(task);

    return res.json({ ok: true, task, queue: global.HC_TASK_QUEUE });
  });

  app.get('/api/hc/tasks', (_req, res) => {
    return res.json({
      ok: true,
      tasks: global.HC_TASK_QUEUE || []
    });
  });

  app.post('/api/hc/bnca', (req, res) => {
    const office = (req.body && req.body.office) || "Scottsdale - Shea";

    return res.json({
      ok: true,
      office,
      updatedAt: new Date().toISOString(),
      summary: "BNCA refreshed for " + office,
      metrics: {
        denialRate: 12.4,
        authDelay: 56,
        queueDepth: 31
      }
    });
  });

};
