#!/bin/bash
# SYNC HUB APP NAMES FROM HTML TITLES
# Reads <title> from each local HTML file and updates hub_index_v3.html names
# Run from: /workspaces/tsm-shell

ROOT="/workspaces/tsm-shell"
HUB="$ROOT/hub_index_v3.html"

echo "=== READING TITLES FROM HTML FILES ==="
echo ""

# Map: key → html file path
declare -A KEY_FILE
KEY_FILE["honorhealth"]="$ROOT/honorhealth-dee.html"
KEY_FILE["hc-command"]="$ROOT/healthcare-command.html"
KEY_FILE["hc-billing"]="$ROOT/hc-billing.tsmatter.html"
KEY_FILE["hc-compliance"]="$ROOT/hc-compliance.tsmatter.html"
KEY_FILE["hc-financial"]="$ROOT/hc-financial.tsmatter.html"
KEY_FILE["hc-grants"]="$ROOT/hc-grants.tsmatter.html"
KEY_FILE["hc-insurance"]="$ROOT/hc-insurance.tsmatter.html"
KEY_FILE["hc-legal"]="$ROOT/hc-legal.tsmatter.html"
KEY_FILE["hc-medical"]="$ROOT/hc-medical.tsmatter.html"
KEY_FILE["hc-pharmacy"]="$ROOT/hc-pharmacy.tsmatter.html"
KEY_FILE["hc-strategist"]="$ROOT/hc-strategist.tsmatter.html"
KEY_FILE["hc-taxprep"]="$ROOT/hc-taxprep.tsmatter.html"
KEY_FILE["hc-vendors"]="$ROOT/hc-vendors.tsmatter.html"
KEY_FILE["dme"]="$ROOT/dme.html"
KEY_FILE["bpo-legal"]="$ROOT/bpo-legal.tsmatter.html"
KEY_FILE["bpo-realty"]="$ROOT/bpo-realty.tsmatter.html"
KEY_FILE["bpo-tax"]="$ROOT/bpo-tax.tsmatter.html"
KEY_FILE["financial-command"]="$ROOT/financial-command.tsmatter.html"
KEY_FILE["desert-financial"]="$ROOT/desert-financial.tsmatter.html"
KEY_FILE["strategist"]="$ROOT/strategist-index.html"
KEY_FILE["construction-command"]="$ROOT/construction-command.tsmatter.html"
KEY_FILE["pc-command"]="$ROOT/pc-command.tsmatter.html"
KEY_FILE["az-ins"]="$ROOT/az-ins.tsmatter.html"
KEY_FILE["rrd-command"]="$ROOT/rrd-command.tsmatter.html"
KEY_FILE["legal-analyst-pro"]="$ROOT/rrd-command.tsmatter.html"
KEY_FILE["case-tech"]="$ROOT/case-tech.tsmatter.html"
KEY_FILE["reo-pro"]="$ROOT/reo-pro.tsmatter.html"
KEY_FILE["agents-ins"]="$ROOT/agents-ins.html"

echo "KEY → FILE TITLE"
echo "----------------"
for key in "${!KEY_FILE[@]}"; do
  file="${KEY_FILE[$key]}"
  if [ -f "$file" ]; then
    title=$(grep -m1 '<title>' "$file" | sed 's/.*<title>\(.*\)<\/title>.*/\1/' | xargs)
    echo "$key → $title"
  else
    echo "$key → ⚠️  FILE NOT FOUND: $file"
  fi
done | sort

echo ""
echo "=== PATCHING hub_index_v3.html LOCAL_APPS names ==="

patch_name() {
  local key="$1"
  local file="${KEY_FILE[$key]}"
  if [ ! -f "$file" ]; then return; fi
  local title=$(grep -m1 '<title>' "$file" | sed 's/.*<title>\(.*\)<\/title>.*/\1/' | xargs)
  if [ -z "$title" ]; then return; fi
  # Replace: { sector:'...', name:'OLD NAME',  key:'KEY' }
  # with:    { sector:'...', name:'NEW TITLE', key:'KEY' }
  sed -i "s|name:'[^']*',\s*key:'$key'|name:'$title', key:'$key'|g" "$HUB"
  sed -i "s|name:\"[^\"]*\",\s*key:\"$key\"|name:\"$title\", key:\"$key\"|g" "$HUB"
  echo "✅ $key → $title"
}

for key in "${!KEY_FILE[@]}"; do
  patch_name "$key"
done

echo ""
echo "=== DONE — verify then deploy ==="
echo "Run: bash predeploy_titles.sh && fly deploy"
