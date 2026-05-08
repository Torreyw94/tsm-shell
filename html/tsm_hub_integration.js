/**
 * tsm_hub_integration.js — TSM Hub → Bridge Connection Layer
 *
 * Drop this into your TSM Hub frontend. Replaces the static/hardcoded
 * compliance card data with live calls to tsm_bridge_v2.py.
 *
 * Usage (in your existing hub JS):
 *   import { analyzeDomain, renderComplianceCard } from './tsm_hub_integration.js';
 *
 * Or include as a <script> tag — the functions attach to window.TSM
 */

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG — update BRIDGE_URL to your deployed bridge host
// ─────────────────────────────────────────────────────────────────────────────

const TSM_CONFIG = {
  // Local dev
  BRIDGE_URL: window.location.hostname === "localhost"
    ? "http://localhost:8080"
    : "https://tsm-shell.fly.dev",   // ← your Fly.io host

  // Default domain if none specified
  DEFAULT_DOMAIN: "compliance",

  // How long to cache a result before re-fetching (ms)
  CACHE_TTL_MS: 5 * 60 * 1000,  // 5 minutes
};

// ─────────────────────────────────────────────────────────────────────────────
// CACHE  (in-memory, per session)
// ─────────────────────────────────────────────────────────────────────────────

const _cache = new Map();

function _cacheKey(clientName, domain) {
  return `${clientName}::${domain}`;
}

function _cacheGet(key) {
  const entry = _cache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.ts > TSM_CONFIG.CACHE_TTL_MS) {
    _cache.delete(key);
    return null;
  }
  return entry.data;
}

function _cacheSet(key, data) {
  _cache.set(key, { data, ts: Date.now() });
}


// ─────────────────────────────────────────────────────────────────────────────
// CORE API CALL
// ─────────────────────────────────────────────────────────────────────────────

/**
 * analyzeDomain — main entry point
 *
 * @param {object} params
 * @param {string} params.clientName   — Display name for the client
 * @param {string} params.source       — File path or DB connection string the bridge can reach
 * @param {string} [params.domain]     — compliance | music | legal | financial
 * @param {string} [params.dbType]     — sqlite | postgres | mysql (for DB sources)
 * @param {object} [params.customQueries] — Override SQL queries for non-standard schemas
 * @param {boolean} [params.useOcr]    — Enable OCR for scanned PDFs
 * @param {boolean} [params.skipCache] — Force fresh fetch
 *
 * @returns {Promise<{metrics: object, analysis: string, client: string, domain: string}>}
 */
async function analyzeDomain({
  clientName,
  source,
  domain = TSM_CONFIG.DEFAULT_DOMAIN,
  dbType,
  customQueries,
  useOcr = false,
  skipCache = false,
} = {}) {

  if (!clientName || !source) {
    throw new Error("analyzeDomain requires clientName and source");
  }

  const cacheKey = _cacheKey(clientName, domain);
  if (!skipCache) {
    const cached = _cacheGet(cacheKey);
    if (cached) {
      console.log(`[TSM] Cache hit: ${cacheKey}`);
      return cached;
    }
  }

  const body = {
    client_name: clientName,
    source,
    domain,
    ...(dbType        && { db_type: dbType }),
    ...(customQueries && { custom_queries: customQueries }),
    ...(useOcr        && { use_ocr: true }),
  };

  console.log(`[TSM] POST /analyze → ${clientName} / ${domain}`);

  const resp = await fetch(`${TSM_CONFIG.BRIDGE_URL}/analyze`, {
    method:  "POST",
    headers: { "Content-Type": "application/json" },
    body:    JSON.stringify(body),
  });

  if (!resp.ok) {
    const err = await resp.json().catch(() => ({ error: resp.statusText }));
    throw new Error(`Bridge error ${resp.status}: ${err.error || resp.statusText}`);
  }

  const data = await resp.json();
  _cacheSet(cacheKey, data);
  return data;
}


// ─────────────────────────────────────────────────────────────────────────────
// CARD RENDERER  — replaces your static compliance card HTML
// ─────────────────────────────────────────────────────────────────────────────

/**
 * renderComplianceCard — injects live analysis into an existing DOM element
 *
 * @param {string|HTMLElement} containerSelector  — CSS selector or DOM node
 * @param {object} analysisResult                 — result from analyzeDomain()
 */
function renderComplianceCard(containerSelector, analysisResult) {
  const container = typeof containerSelector === "string"
    ? document.querySelector(containerSelector)
    : containerSelector;

  if (!container) {
    console.warn("[TSM] renderComplianceCard: container not found:", containerSelector);
    return;
  }

  const { metrics = {}, analysis = "", client, domain } = analysisResult;

  const fmt = (val, prefix = "$") =>
    val != null ? `${prefix}${Number(val).toLocaleString()}` : "—";

  const pct = (val) =>
    val != null ? `${val}%` : "—";

  const gapList = (metrics.compliance_gaps || [])
    .map(g => `<li class="tsm-gap">${g}</li>`)
    .join("") || "<li>No gaps identified in source data.</li>";

  container.innerHTML = `
    <div class="tsm-card tsm-card--live">

      <div class="tsm-card__header">
        <span class="tsm-badge tsm-badge--live">● LIVE</span>
        <h2 class="tsm-card__title">
          ${_domainLabel(domain)} — ${_escHtml(client)}
        </h2>
        <button class="tsm-card__refresh" onclick="window.TSM.refresh('${_escHtml(containerSelector)}')">
          ↻ Refresh
        </button>
      </div>

      <div class="tsm-card__metrics">
        <div class="tsm-metric">
          <span class="tsm-metric__label">Total Billed</span>
          <span class="tsm-metric__value">${fmt(metrics.total_billed)}</span>
        </div>
        <div class="tsm-metric">
          <span class="tsm-metric__label">Total Paid</span>
          <span class="tsm-metric__value">${fmt(metrics.total_paid)}</span>
        </div>
        <div class="tsm-metric tsm-metric--risk">
          <span class="tsm-metric__label">Revenue at Risk</span>
          <span class="tsm-metric__value">${fmt(metrics.revenue_at_risk)}</span>
        </div>
        <div class="tsm-metric ${metrics.denial_rate_pct > 10 ? 'tsm-metric--alert' : ''}">
          <span class="tsm-metric__label">Denial Rate</span>
          <span class="tsm-metric__value">${pct(metrics.denial_rate_pct)}</span>
        </div>
        <div class="tsm-metric ${metrics.overdue_exclusion_screenings > 0 ? 'tsm-metric--alert' : ''}">
          <span class="tsm-metric__label">Overdue Screenings</span>
          <span class="tsm-metric__value">${metrics.overdue_exclusion_screenings ?? "—"}</span>
        </div>
        <div class="tsm-metric">
          <span class="tsm-metric__label">Staff Total</span>
          <span class="tsm-metric__value">${metrics.staff_total ?? "—"}</span>
        </div>
      </div>

      <div class="tsm-card__gaps">
        <h3>Compliance Gaps</h3>
        <ul>${gapList}</ul>
      </div>

      <div class="tsm-card__analysis">
        <h3>AI Analysis <span class="tsm-model-tag">llama-3.3-70b</span></h3>
        <pre class="tsm-analysis-text">${_escHtml(analysis)}</pre>
      </div>

      <div class="tsm-card__footer">
        Source: ${_escHtml(metrics.source_type || "Unknown")} ·
        Fetched: ${new Date().toLocaleTimeString()}
      </div>

    </div>
  `;
}


// ─────────────────────────────────────────────────────────────────────────────
// LOADING + ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

function renderLoading(containerSelector, message = "Fetching client data…") {
  const el = typeof containerSelector === "string"
    ? document.querySelector(containerSelector)
    : containerSelector;
  if (el) el.innerHTML = `
    <div class="tsm-card tsm-card--loading">
      <div class="tsm-spinner"></div>
      <p>${message}</p>
    </div>`;
}

function renderError(containerSelector, error) {
  const el = typeof containerSelector === "string"
    ? document.querySelector(containerSelector)
    : containerSelector;
  if (el) el.innerHTML = `
    <div class="tsm-card tsm-card--error">
      <h3>⚠ Bridge Error</h3>
      <pre>${_escHtml(String(error))}</pre>
      <button onclick="location.reload()">Retry</button>
    </div>`;
}


// ─────────────────────────────────────────────────────────────────────────────
// HIGH-LEVEL HELPER — load + render in one call
// ─────────────────────────────────────────────────────────────────────────────

/**
 * loadCard — fetches + renders a compliance card in one call.
 * This is what you call from your hub's page init.
 *
 * Example:
 *   TSM.loadCard({
 *     container: "#compliance-card",
 *     clientName: "Acme Health",
 *     source: "/data/acme_claims.csv",
 *     domain: "compliance",
 *   });
 */
async function loadCard({
  container,
  clientName,
  source,
  domain = "compliance",
  dbType,
  customQueries,
  useOcr = false,
  skipCache = false,
} = {}) {

  renderLoading(container, `Loading ${domain} data for ${clientName}…`);

  try {
    const result = await analyzeDomain({
      clientName, source, domain, dbType, customQueries, useOcr, skipCache,
    });
    renderComplianceCard(container, result);
  } catch (err) {
    console.error("[TSM] loadCard error:", err);
    renderError(container, err.message);
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// MULTI-CLIENT BATCH LOADER
// for dashboards showing multiple clients at once
// ─────────────────────────────────────────────────────────────────────────────

/**
 * loadAll — loads multiple client cards concurrently
 *
 * @param {Array<object>} cards — array of loadCard param objects
 */
async function loadAll(cards = []) {
  await Promise.allSettled(cards.map(card => loadCard(card)));
}


// ─────────────────────────────────────────────────────────────────────────────
// REFRESH (bound to ↻ button in card HTML)
// ─────────────────────────────────────────────────────────────────────────────

// Store last params per container so refresh can re-use them
const _lastParams = new Map();

async function refresh(containerSelector) {
  const params = _lastParams.get(containerSelector);
  if (!params) {
    console.warn("[TSM] No params stored for refresh:", containerSelector);
    return;
  }
  await loadCard({ ...params, skipCache: true });
}


// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function _escHtml(str = "") {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function _domainLabel(domain) {
  const labels = {
    compliance: "OIG/CMS Compliance",
    music:      "Music Royalties",
    legal:      "Legal & Contracts",
    financial:  "Financial Audit",
  };
  return labels[domain] || domain;
}


// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC API — attach to window.TSM for script-tag usage
// ─────────────────────────────────────────────────────────────────────────────

window.TSM = {
  analyzeDomain,
  renderComplianceCard,
  loadCard,
  loadAll,
  refresh,
  config: TSM_CONFIG,
};

// ES module export (for bundler / import usage)
export {
  analyzeDomain,
  renderComplianceCard,
  loadCard,
  loadAll,
  refresh,
  TSM_CONFIG,
};
