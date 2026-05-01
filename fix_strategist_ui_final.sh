#!/usr/bin/env bash
set -e

FILE="/workspaces/tsm-shell/html/main-strategist/index.html"

echo "🔧 Cleaning Strategist UI runtime..."

# 1. Remove broken onclick showTab calls
sed -i 's/onclick="showTab([^"]*)"//g' "$FILE"

# 2. Inject safe tab system
if ! grep -q "TSM_STRATEGIST_TABS" "$FILE"; then
cat >> "$FILE" <<'JS'

<script>
// ===== TSM STRATEGIST SAFE TAB SYSTEM =====
(function(){
  window.showTab = function(tab){
    document.querySelectorAll('[data-tab]').forEach(el=>{
      el.style.display = (el.dataset.tab === tab) ? 'block' : 'none';
    });
  };
})();
</script>

JS
fi

# 3. Fix broken try blocks (safe fallback)
sed -i 's/try {/try {\n/g' "$FILE"

echo "✅ Strategist UI stabilized"
