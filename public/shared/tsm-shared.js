const SovereignGuard = {
    activeSectors: new Set(['construction', 'insurance', 'healthcare', 'finops']),
    triggerKillswitch: function(sector) {
        console.error("🚨 ALERT: Killswitch activated for " + sector.toUpperCase());
        this.activeSectors.delete(sector.toLowerCase());
        const btn = document.querySelector(`button[onclick*='${sector}']`);
        if(btn) {
            btn.disabled = true;
            btn.style.background = "#550000";
            btn.innerText = "NODE KILLED";
        }
    }
};

const AuditOpsGLEngine = {
    calculateGLReconciliation: function(actual, estimated, rate) {
        const adj = ((actual - estimated) / 1000) * rate;
        return {
            type: "General Liability",
            basis: "Gross Sales",
            actual: actual.toLocaleString('en-US', { style: 'currency', currency: 'USD' }),
            adjustment: adj.toLocaleString('en-US', { style: 'currency', currency: 'USD' }),
            impact: adj > 0 ? "Under-reported exposure" : "Over-reported"
        };
    }
};

// Ensure setSector is wrapped only AFTER it is defined
window.addEventListener('load', () => {
    if (window.setSector) {
        const _orig = window.setSector;
        window.setSector = (sector) => {
            if (!SovereignGuard.activeSectors.has(sector.toLowerCase())) {
                alert("CRITICAL ERROR: Node [" + sector + "] is locked/inactive.");
                return;
            }
            _orig(sector);
        };
    }
});
