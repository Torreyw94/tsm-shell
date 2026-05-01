#!/bin/bash

# activate_zero_trust_finops.sh
# Activate Zero-Trust HTML module in finops-suite
# Usage: ./activate_zero_trust_finops.sh

set -e

FINOPS_SUITE="html/finops-suite"
SRC_ZERO_TRUST="html/zero-trust.html"
DEST_ZERO_TRUST="$FINOPS_SUITE/zero-trust.html"

echo "🔒 Activating Zero-Trust in FinOps suite..."

# 1. Copy zero-trust.html to finops-suite
if [ ! -f "$DEST_ZERO_TRUST" ]; then
  echo "📋 Copying zero-trust.html to finops-suite..."
  cp "$SRC_ZERO_TRUST" "$DEST_ZERO_TRUST"
  echo "✅ Copied successfully"
else
  echo "ℹ️  Zero-trust.html already exists in finops-suite"
fi

# 2. Update finops-presentation/index.html to add Zero-Trust card
PRESENTATION="$FINOPS_SUITE/finops-presentation/index.html"
if ! grep -q "ZERO TRUST" "$PRESENTATION"; then
  echo "📝 Updating finops-presentation with Zero-Trust card..."
  
  # Create backup
  cp "$PRESENTATION" "${PRESENTATION}.bak.$(date +%s)"
  
  # Add Zero-Trust card after the Financial Intelligence card
  # Using a more reliable approach with sed
  sed -i '/FINOPS MAIN STRATEGIST/i\
\  <section class="card">\
    <h2>3A · ZERO TRUST ACCESS CONTROL</h2>\
    <p>QuickBooks & financial system access audit. Identity, role, and credential review.</p>\
    <div class="metric"><b>7</b><br>user roles</div>\
    <div class="metric"><b>3</b><br>risk items</div>\
    <div class="metric"><b>12</b><br>access logs</div>\
    <div class="output">Zero Trust scans QuickBooks, accounting software, and payment processor access for overprivileging and credential risk.</div>\
    <button onclick="location.href='\''/html/finops-suite/zero-trust.html?v=finops-demo'\''">OPEN ZERO TRUST AUDIT</button>\
  </section>\
' "$PRESENTATION"
  
  echo "✅ Updated finops-presentation"
else
  echo "ℹ️  Zero-Trust card already exists in finops-presentation"
fi

# 3. Update server-side flow description if present
PRESENTATION="$FINOPS_SUITE/finops-presentation/index.html"
if ! grep -q "Zero Trust =" "$PRESENTATION"; then
  echo "📝 Adding Zero-Trust to workflow explanation..."
  
  # Backup already made above
  sed -i 's/Compliance Shield = What documentation or approval gaps could create audit risk./Compliance Shield = What documentation or approval gaps could create audit risk.\nZero Trust = Who has access to financial systems; credential and role audit./' "$PRESENTATION"
  
  echo "✅ Added Zero-Trust description"
fi

# 4. Commit changes
echo "💾 Committing changes..."
git add "$DEST_ZERO_TRUST" "$PRESENTATION"
git commit -m "Activate Zero-Trust module in finops-suite with access control card" || echo "ℹ️  No changes to commit"

echo ""
echo "✨ Zero-Trust FinOps activation complete!"
echo "📍 Access at: /finops/zero-trust.html"
echo "🎯 Card added to finops-presentation as step 3A in workflow"
