(function(global) {
    const SovereignCompliance = {
        term: "2022-2026",
        renewalDate: "2026-05-31", // Target based on May Birth Month
        requiredHours: 48,         // Total CE (ARS § 20-2902)
        requiredEthics: 6,         // Mandatory Ethics component
        addressNotificationWindow: 30, // Days to report changes (ARS § 20-286)

        checkDIFIStatus: function(hours, ethics) {
            const hLeft = Math.max(0, this.requiredHours - hours);
            const eLeft = Math.max(0, this.requiredEthics - ethics);
            const today = new Date();
            const expiry = new Date(this.renewalDate);
            const late = today > expiry;
            
            return {
                status: (hLeft === 0 && eLeft === 0) ? "COMPLIANT" : "RENEWAL ACTION REQUIRED",
                totalFee: late ? 220.00 : 120.00, // Includes $100 late penalty
                auditRisk: (hLeft > 0 || eLeft > 0) ? "HIGH: Potential License Lapse" : "LOW",
                remaining: `Complete ${hLeft}h total, including ${eLeft}h Ethics.`
            };
        }
    };

    // Global Sovereign Guard - ARS § 20-290 Audit Logic
    const SovereignGuard = {
        isArmed: true,
        retentionDeadline: (date) => {
            const d = new Date(date);
            d.setFullYear(d.getFullYear() + 3); // 3-year mandate
            return d.toLocaleDateString();
        }
    };

    // Explicitly attach to global scope
    global.SovereignCompliance = SovereignCompliance;
    global.SovereignGuard = SovereignGuard;
    
    console.info("%c🛡️ SOVEREIGN MESH: 2026 AZ COMPLIANCE ATTACHED", "color: #00f2ff; font-weight: bold;");
})(typeof window !== 'undefined' ? window : global);
