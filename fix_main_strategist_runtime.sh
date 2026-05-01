#!/usr/bin/env bash
set -e

FILE="/workspaces/tsm-shell/html/main-strategist/index.html"

echo "🔧 Fixing strategist runtime..."

if ! grep -q "function showTab" "$FILE"; then
cat >> "$FILE" <<'JS'

<script>
// ===== TSM STRATEGIST TAB HANDLER =====
function showTab(tab){
  try {
    document.querySelectorAll('[data-tab]').forEach(el => {
      el.style.display = (el.dataset.tab === tab) ? 'block' : 'none';
    });
  } catch(e){
    console.warn("showTab fallback:", e);
  }
}
</script>

JS
fi

sed -i 's/try {/try {\n/g' "$FILE"

echo "✅ Strategist runtime fully patched"
