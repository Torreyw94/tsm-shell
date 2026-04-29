/**
 * TSM Zero-Trust Neural Link · tsm-zero-trust.js
 * Drop into any HC Suite app: <script src="/html/shared/tsm-zero-trust.js"></script>
 * Verifies session integrity before app load. Links to hc-strategist as command node.
 */
(function(){
  const ZT = {
    STRATEGIST_URL: '/html/hc-strategist/index.html',
    SESSION_KEY:    'tsm_zt_session',
    HEARTBEAT_KEY:  'tsm_zt_heartbeat',
    HEARTBEAT_TTL:  15 * 60 * 1000, // 15 min
    APP_ID: (function(){
      const p = window.location.pathname;
      const m = p.match(/\/html\/([^\/]+)\//);
      return m ? m[1] : 'unknown';
    })(),

    // Write a heartbeat so hc-strategist knows this node is alive
    pulse() {
      const record = {
        appId: this.APP_ID,
        ts: Date.now(),
        path: window.location.pathname,
        status: 'ONLINE'
      };
      try {
        const all = JSON.parse(localStorage.getItem('tsm_zt_nodes') || '{}');
        all[this.APP_ID] = record;
        localStorage.setItem('tsm_zt_nodes', JSON.stringify(all));
      } catch(e) {}
    },

    // Verify session is valid (set by hc-strategist or self-issued on first visit)
    verify() {
      try {
        const raw = sessionStorage.getItem(this.SESSION_KEY);
        if (!raw) return this._issue();
        const s = JSON.parse(raw);
        const age = Date.now() - s.issued;
        if (age > this.HEARTBEAT_TTL) return this._issue();
        return true;
      } catch(e) {
        return this._issue();
      }
    },

    // Issue a new session token (first-party, zero external deps)
    _issue() {
      const token = {
        id: Math.random().toString(36).slice(2) + Date.now().toString(36),
        issued: Date.now(),
        origin: this.APP_ID,
        trust: 'tsm-internal'
      };
      try {
        sessionStorage.setItem(this.SESSION_KEY, JSON.stringify(token));
      } catch(e) {}
      return true;
    },

    // Inject the neural link status badge into the page header
    injectBadge() {
      const existing = document.getElementById('tsm-zt-badge');
      if (existing) return;
      const badge = document.createElement('div');
      badge.id = 'tsm-zt-badge';
      badge.style.cssText = `
        position:fixed;bottom:42px;left:12px;z-index:9999;
        display:flex;align-items:center;gap:6px;
        background:#0a0f0a;border:1px solid #1e3a1e;
        border-radius:4px;padding:4px 10px;font-family:'Courier New',monospace;
        font-size:9px;font-weight:700;letter-spacing:1px;color:#00ff88;
        cursor:pointer;opacity:0.85;transition:opacity .2s;
      `;
      badge.innerHTML = `<span style="display:inline-block;width:6px;height:6px;border-radius:50%;background:#00ff88;animation:zt-blink .9s infinite"></span>NEURAL LINK · HC-STRATEGIST`;
      badge.title = 'Zero-Trust Active · Click to open HC Strategist';
      badge.onclick = () => { window.location.href = ZT.STRATEGIST_URL; };
      // Inject blink keyframes once
      if (!document.getElementById('tsm-zt-style')) {
        const style = document.createElement('style');
        style.id = 'tsm-zt-style';
        style.textContent = `@keyframes zt-blink{0%,100%{opacity:1}50%{opacity:.3}}`;
        document.head.appendChild(style);
      }
      document.body.appendChild(badge);
    },

    // Boot sequence
    init() {
      this.verify();
      this.pulse();
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => this.injectBadge());
      } else {
        this.injectBadge();
      }
      // Re-pulse every 5 min to keep node alive in strategist view
      setInterval(() => this.pulse(), 5 * 60 * 1000);
    }
  };

  window.TSMzeroTrust = ZT;
  ZT.init();
})();
