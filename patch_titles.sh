#!/bin/bash
# ONE-SHOT TITLE PATCHER — TSM-SHELL
# Run from: /workspaces/tsm-shell

ROOT="/workspaces/tsm-shell"
HTML="$ROOT/html"

patch_title() {
  local file="$1"
  local title="$2"
  if [ -f "$file" ]; then
    sed -i "s|<title>.*</title>|<title>$title</title>|" "$file"
    echo "✅ $file → $title"
  else
    echo "⚠️  NOT FOUND: $file"
  fi
}

echo "=== PATCHING TITLES ==="

patch_title "$ROOT/az-ins.tsmatter.html"                "AZ Insurance Command"
patch_title "$ROOT/bpo-legal.tsmatter.html"             "BPO Legal Command"
patch_title "$ROOT/bpo-realty.tsmatter.html"            "BPO Realty Command"
patch_title "$ROOT/bpo-tax.tsmatter.html"               "BPO Tax Command"
patch_title "$ROOT/case-tech.tsmatter.html"             "Case-Tech Command"
patch_title "$ROOT/construction-command.tsmatter.html"  "TSM | Construction Command"
patch_title "$ROOT/desert-financial.tsmatter.html"      "Desert Financial Command"
patch_title "$ROOT/financial-command.tsmatter.html"     "TSM | Financial Command"
patch_title "$ROOT/hc-billing.tsmatter.html"            "HC Billing Command"
patch_title "$ROOT/hc-compliance.tsmatter.html"         "HC Compliance Command"
patch_title "$ROOT/hc-financial.tsmatter.html"          "HC Financial Command"
patch_title "$ROOT/hc-grants.tsmatter.html"             "HC Grants Command"
patch_title "$ROOT/hc-insurance.tsmatter.html"          "HC Insurance Command"
patch_title "$ROOT/hc-legal.tsmatter.html"              "HC Legal Command"
patch_title "$ROOT/hc-medical.tsmatter.html"            "HC Medical Command"
patch_title "$ROOT/hc-pharmacy.tsmatter.html"           "HC Pharmacy Command"
patch_title "$ROOT/hc-strategist.tsmatter.html"         "HC Strategist Command"
patch_title "$ROOT/hc-taxprep.tsmatter.html"            "HC Tax Prep Command"
patch_title "$ROOT/hc-vendors.tsmatter.html"            "HC Vendors Command"
patch_title "$ROOT/healthcare-command.html"             "TSM | Healthcare Command"
patch_title "$ROOT/index.html"                          "TSM Shell"
patch_title "$ROOT/pc-command.tsmatter.html"            "PC Command"
patch_title "$ROOT/reo-pro.tsmatter.html"               "REO Pro Command"
patch_title "$ROOT/rrd-command.tsmatter.html"           "RRD Command"
patch_title "$ROOT/strategist00.tsmatter.html"          "Sovereign Strategist"
patch_title "$HTML/financial-command.html"              "TSM | Financial Command"

echo ""
echo "=== VERIFYING ==="
for f in "$ROOT"/*.html "$HTML"/*.html; do
  title=$(grep -m1 '<title>' "$f" 2>/dev/null | sed 's/.*<title>\(.*\)<\/title>.*/\1/' | xargs)
  echo "$(basename $f) → $title"
done
