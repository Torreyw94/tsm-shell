// groq-bridge.js — drop <script src="/groq-bridge.js"></script> into every page

window.GroqBridge = {
  // Core call — all other methods use this
  async ask(userPrompt, system = "") {
    const res = await fetch("/api/financial/query", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        system: system || undefined,
        user: userPrompt,
        query: userPrompt,
        maxTokens: 1024
      }),
    });
    if (!res.ok) throw new Error(`Groq error ${res.status}`);
    const data = await res.json();
    return data.answer || data.content || 'No response.';
  },

  // ── Doc Showcase ─────────────────────────────────────────────────────────────

  engines: {
    "01": {
      label: "Document Triage & Flag Analysis",
      system: "You are a FinOps controller. Be concise, specific, use dollar amounts.",
      prompt: (docText) =>
        `Analyze this financial document. Return:\n1. RISK LEVEL (LOW/MEDIUM/HIGH/CRITICAL)\n2. KEY FLAGS (3-5 specific issues with $ amounts)\n3. IMMEDIATE ACTIONS (next 24-48 hrs)\n4. CONTROLLER ALERT (one sentence)\n\nDocument:\n${docText}`,
    },
    "02": {
      label: "Variance & Risk Intelligence",
      system: "You are a FinOps risk analyst. Be quantitative.",
      prompt: (docText) =>
        `Analyze for variance and risk. Return:\n1. VARIANCE MATRIX (actual vs expected, $ and %)\n2. RISK SCORING (LOW/MEDIUM/HIGH per item)\n3. TREND SIGNALS\n4. CFO TALKING POINTS (2-3 bullets)\n\nDocument:\n${docText}`,
    },
    "03": {
      label: "Controller Action Plan · BNCA",
      system: "You are a controller and FinOps strategist using BNCA format.",
      prompt: (docText) =>
        `Create a BNCA action plan:\nBACKGROUND: current state (2-3 sentences)\nNEXT STEPS: 5 items with owner (Controller/AP/AR/CFO) and deadline\nCONSTRAINTS: 2-3 blockers\nACCOUNTABILITY: owner and resolution date\n\nDocument:\n${docText}`,
    },
    "04": {
      label: "CFO Executive Intelligence",
      system: "You are a CFO advisor. Write for C-suite. Direct, no jargon.",
      prompt: (docText) =>
        `Generate CFO executive intelligence:\n1. EXECUTIVE SUMMARY (3-4 sentences)\n2. BOARD-LEVEL RISK (if any)\n3. STRATEGIC IMPLICATIONS\n4. CFO ACTIONS (3 decisions needed this week)\n\nDocument:\n${docText}`,
    },
  },

  async fireEngine(engineId, docText, onResult) {
    const engine = this.engines[engineId];
    if (!engine) throw new Error(`Unknown engine ${engineId}`);
    const result = await this.ask(engine.prompt(docText), engine.system);
    if (onResult) onResult(engineId, result);
    return result;
  },

  async fireAllEngines(docText, onResult, onDone) {
    const ids = Object.keys(this.engines);
    await Promise.all(ids.map((id) => this.fireEngine(id, docText, onResult)));
    if (onDone) onDone();
  },

  // ── Financial Suite modules ───────────────────────────────────────────────

  modules: {
    "financial-command": {
      system: "You are a FinOps controller running daily ops.",
      prompt: (ctx) =>
        `Daily Financial Command briefing:\n1. CRITICAL ALERTS (top 3, with $)\n2. AR PRIORITY (what to collect today)\n3. AP STATUS (due, holds, disputes)\n4. COMPLIANCE SCORE (1-10 + gaps)\n5. CONTROLLER NEXT ACTION (single most urgent task)\n\nContext: ${ctx}`,
    },
    "financial-intel": {
      system: "You are a nonprofit fund accountant (ASC 958).",
      prompt: (ctx) =>
        `Financial Intelligence report:\n1. FUND ACCOUNTING STATUS (restricted vs unrestricted)\n2. GRANT COMPLIANCE (burn rate, reporting deadlines)\n3. FORM 990 READINESS (% complete, missing items)\n4. AUDIT EXPOSURE (top 3 risk areas)\n5. BOARD REPORTING (what finance committee needs)\n\nContext: ${ctx}`,
    },
    "controller-action-plan": {
      system: "You are a FinOps strategist.",
      prompt: (ctx) =>
        `Controller Action Plan (BNCA):\nBACKGROUND / NEXT STEPS / CONSTRAINTS / ACCOUNTABILITY\nAlso: AUTOMATION OPPORTUNITIES + NODE STATUS\n\nContext: ${ctx}`,
    },
    "tax-prep": {
      system: "You are a tax accountant specializing in 1099 compliance.",
      prompt: (ctx) =>
        `Tax Prep Readiness Report:\n1. 1099 THRESHOLD REVIEW (vendors at/near $600)\n2. W-9 GAPS (sorted by payment amount)\n3. FILING TIMELINE (key IRS deadlines)\n4. FILING RISK SCORE (+ penalty exposure)\n5. IMMEDIATE ACTIONS (this week)\n\nContext: ${ctx}`,
    },
    "compliance-shield": {
      system: "You are an audit compliance specialist.",
      prompt: (ctx) =>
        `Compliance Shield Report:\n1. APPROVAL GAPS (missing approvals by risk)\n2. DOCUMENT COMPLETENESS (%)\n3. AUDIT TRAIL HEALTH\n4. POLICY VIOLATIONS (severity)\n5. PRE-AUDIT ACTION PLAN (5 fixes)\n\nContext: ${ctx}`,
    },
    "zero-trust": {
      system: "You are a financial systems security specialist.",
      prompt: (ctx) =>
        `Zero Trust Access Report:\n1. ACCESS ANOMALIES\n2. QUICKBOOKS RISK (admin accounts, roles, exports)\n3. DATA EXPOSURE SCORE (1-10)\n4. TERMINATED EMPLOYEE CHECK\n5. REMEDIATION PLAN (priority order)\n\nContext: ${ctx}`,
    },
    "finops-suite": {
      system: "You are a FinOps operations manager.",
      prompt: (ctx) =>
        `FinOps Operations Suite Status:\n1. WORKFLOW STATUS (active, stuck, completion rate)\n2. TEAM CAPACITY (AP/AR/close/reporting)\n3. AUTOMATION WINS\n4. BOTTLENECKS (top 3 + root cause)\n5. EFFICIENCY METRICS (invoice cycle, recon time, close days)\n\nContext: ${ctx}`,
    },
    "accounting-poc": {
      system: "You are a FinOps AI implementation specialist.",
      prompt: (ctx) =>
        `Accounting Doc POC Status:\n1. AI EXTRACTION ACCURACY (by doc type)\n2. PROCESSING METRICS (docs/hr, exception rate)\n3. EXCEPTION ANALYSIS (what AI gets wrong)\n4. ROI CALCULATION (time saved, FTE, cost/doc)\n5. GO-LIVE READINESS (% ready, remaining gaps)\n\nContext: ${ctx}`,
    },
  },

  async runModule(moduleId, context = "No additional context provided.") {
    const mod = this.modules[moduleId];
    if (!mod) throw new Error(`Unknown module ${moduleId}`);
    return await this.ask(mod.prompt(context), mod.system);
  },
};

// ── Auto-wire: hooks for the existing page buttons ─────────────────────────

document.addEventListener("DOMContentLoaded", () => {
  // Wire "FIRE ALL 4 ENGINES" button on finops-showcase-v2.html
  const fireBtn = document.querySelector('[data-action="fire-engines"], .fire-btn, #fireAllBtn');
  if (fireBtn) {
    fireBtn.addEventListener("click", async () => {
      const docText = window.__selectedDocText || "No document loaded.";
      const panels = {
        "01": document.querySelector('[data-engine="01"] .engine-output, #engine01'),
        "02": document.querySelector('[data-engine="02"] .engine-output, #engine02'),
        "03": document.querySelector('[data-engine="03"] .engine-output, #engine03'),
        "04": document.querySelector('[data-engine="04"] .engine-output, #engine04'),
      };
      Object.values(panels).forEach((el) => { if (el) el.textContent = "Analyzing…"; });
      await GroqBridge.fireAllEngines(docText, (id, result) => {
        if (panels[id]) panels[id].textContent = result;
      });
    });
  }

  // Wire "OPEN X →" buttons on financial-ui.html
  document.querySelectorAll("[data-module]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const moduleId = btn.dataset.module;
      const output = document.querySelector(`[data-module-output="${moduleId}"]`);
      if (!output) return;
      output.textContent = "Loading…";
      try {
        output.textContent = await GroqBridge.runModule(moduleId);
      } catch (e) {
        output.textContent = `Error: ${e.message}`;
      }
    });
  });
});
