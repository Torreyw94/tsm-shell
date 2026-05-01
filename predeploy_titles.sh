#!/bin/bash
# PRE-DEPLOY TITLE SYNC — TSM-SHELL
# Ensures all HTML files have correct titles before deploying
# Usage: bash predeploy_titles.sh && fly deploy

ROOT="/workspaces/tsm-shell"
HTML="$ROOT/html"
ERRORS=0

patch_title() {
  local file="$1"
  local title="$2"
  if [ -f "$file" ]; then
    sed -i "s#<title>.*</title>#<title>$title</title>#" "$file"
    actual=$(grep -m1 '<title>' "$file" | sed 's/.*<title>\(.*\)<\/title>.*/\1/' | xargs)
    if [ "$actual" = "$title" ]; then
      echo "✅ $(basename $file) → $title"
    else
      echo "❌ FAILED: $(basename $file) — got: $actual"
      ERRORS=$((ERRORS + 1))
    fi
  else
    echo "⚠️  SKIPPED (not found): $file"
  fi
}

echo "======================================"
echo " TSM-SHELL PRE-DEPLOY TITLE SYNC"
echo "======================================"
echo ""

# ROOT files
patch_title "$ROOT/access.html"                          "TSM Matter · Client Portal"
patch_title "$ROOT/agents-ins.html"                      "TSM Insurance Intelligence — AI for Insurance Professionals"
patch_title "$ROOT/auditops-pro.html"                    "AuditOps Pro · TSM AI Tax Intelligence Platform"
patch_title "$ROOT/az-ins.tsmatter.html"                 "AZ Insurance Command"
patch_title "$ROOT/az-life.html"                         "AZ Insurance Command · NPN 18818059"
patch_title "$ROOT/bpo-legal.tsmatter.html"              "BPO Legal Command"
patch_title "$ROOT/bpo-realty.tsmatter.html"             "BPO Realty Command"
patch_title "$ROOT/bpo-tax.tsmatter.html"                "BPO Tax Command"
patch_title "$ROOT/case-tech.tsmatter.html"              "Case-Tech Command"
patch_title "$ROOT/client-access.html"                   "TSM Client Access — Sovereign Intelligence Portal"
patch_title "$ROOT/concierge-command.html"               "TSM | Concierge Command"
patch_title "$ROOT/construction-center.html"             "TSM | Construction Command"
patch_title "$ROOT/construction-command.tsmatter.html"   "TSM | Construction Command"
patch_title "$ROOT/construction.html"                    "Construction Operations Intelligence"
patch_title "$ROOT/desert-financial.tsmatter.html"       "Desert Financial Command"
patch_title "$ROOT/dme.html"                             "Medicare DME Benefits — What Medicare Pays For | TSM Matter"
patch_title "$ROOT/financial-command.tsmatter.html"      "TSM | Financial Command"
patch_title "$ROOT/financial.html"                       "TSM Financial Intelligence Pro"
patch_title "$ROOT/hc-billing.tsmatter.html"             "HC Billing Command"
patch_title "$ROOT/hc-compliance.tsmatter.html"          "HC Compliance Command"
patch_title "$ROOT/hc-financial.tsmatter.html"           "HC Financial Command"
patch_title "$ROOT/hc-grants.tsmatter.html"              "HC Grants Command"
patch_title "$ROOT/hc-insurance.tsmatter.html"           "HC Insurance Command"
patch_title "$ROOT/hc-legal.tsmatter.html"               "HC Legal Command"
patch_title "$ROOT/hc-medical.tsmatter.html"             "HC Medical Command"
patch_title "$ROOT/hc-pharmacy.tsmatter.html"            "HC Pharmacy Command"
patch_title "$ROOT/hc-strategist.tsmatter.html"          "HC Strategist Command"
patch_title "$ROOT/hc-taxprep.tsmatter.html"             "HC Tax Prep Command"
patch_title "$ROOT/hc-vendors.tsmatter.html"             "HC Vendors Command"
patch_title "$ROOT/healthcare-command.html"              "TSM | Healthcare Command"
patch_title "$ROOT/honorhealth-dee.html"                 "TSM · Honor Health — Executive Briefing for Dee"
patch_title "$ROOT/hub-index-v4.html"                    "TSM Hub"
patch_title "$ROOT/hub-index.html"                       "TSM Hub"
patch_title "$ROOT/hub_index.html"                       "TSM Hub"
patch_title "$ROOT/hub_index_v2.html"                    "TSM Hub"
patch_title "$ROOT/hub_index_v3.html"                    "TSM Hub"
patch_title "$ROOT/index.html"                           "TSM Shell"
patch_title "$ROOT/mortgage-command.html"                "TSM | Mortgage Command"
patch_title "$ROOT/pc-command.tsmatter.html"             "PC Command"
patch_title "$ROOT/reo-command.html"                     "Real Estate Command"
patch_title "$ROOT/reo-pro.tsmatter.html"                "REO Pro Command"
patch_title "$ROOT/rrd-command.tsmatter.html"            "RRD Command"
patch_title "$ROOT/schools-command.html"                 "TSM School Command Center"
patch_title "$ROOT/strategist-index.html"                "Sovereign Strategist | The Ultimate Business Consultant"
patch_title "$ROOT/strategist00.tsmatter.html"           "Sovereign Strategist"
patch_title "$ROOT/suite-builder.html"                   "TSM · Presentation Suite Builder"
patch_title "$ROOT/tsm-honorhealth-dee.tsmatter.html"    "TSM · Honor Health — Executive Briefing for Dee"
patch_title "$ROOT/zero-trust.html"                      "TSM Zero-Trust | Enterprise Access Command"

# HTML subdirectory
patch_title "$HTML/az-life.html"                         "AZ Insurance Command · NPN 18818059"
patch_title "$HTML/bnca-gtm-hc.html"                     "BNCA Healthcare GTM Study Page · TSM Command Mode"
patch_title "$HTML/compliance.html"                      "TSM Compliance Command | AI-Powered Regulatory Intelligence"
patch_title "$HTML/desert-pitch.html"                    "TSM × Desert Financial — Strategic Partnership Proposal"
patch_title "$HTML/dme.html"                             "Medicare DME Benefits — What Medicare Pays For | TSM Matter"
patch_title "$HTML/financial-command.html"               "TSM | Financial Command"
patch_title "$HTML/financial.html"                       "TSM Financial Intelligence Pro"
patch_title "$HTML/go-to-market.html"                    "BNCA Healthcare GTM Study Page · TSM Command Mode"
patch_title "$HTML/index.html"                           "TSM Shell"
patch_title "$HTML/pricing1.html"                        "TSMatter · Pricing"
patch_title "$HTML/strategist-index.html"                "Sovereign Strategist | The Ultimate Business Consultant"
patch_title "$HTML/suite-builder.html"                   "TSM · Presentation Suite Builder"
patch_title "$HTML/tax-prep.html"                        "AuditOps Pro · TSM AI Tax Intelligence Platform"
patch_title "$HTML/tsm-strategy.html"                    "TSM Matter — Master Strategy & RRD Pitch"
patch_title "$HTML/zero-trust.html"                      "TSM Zero-Trust | Enterprise Access Command"

echo ""
echo "======================================"
if [ $ERRORS -eq 0 ]; then
  echo " ✅ ALL TITLES SYNCED — safe to deploy"
  echo "======================================"
  echo ""
  echo "Run: fly deploy"
else
  echo " ❌ $ERRORS ERROR(S) — fix before deploying"
  echo "======================================"
  exit 1
fi
