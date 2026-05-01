#!/bin/bash
# ══════════════════════════════════════════════════════
#  TSM FIND & FIX — reusable string replacement tool
#
#  USAGE:
#    bash fix-pricing.sh                         # interactive
#    bash fix-pricing.sh "1,750" "2,000"         # custom find/replace
#    bash fix-pricing.sh "1,750" "2,000" --dry   # dry run only, no changes
#    bash fix-pricing.sh "1,750" "2,000" --live  # skip prompt, apply immediately
#    bash fix-pricing.sh "1,750" "2,000" --skip-backups --live
#
#  FLAGS:
#    --dry           scan only, never write
#    --live          apply without confirmation prompt
#    --skip-backups  exclude _backup_* and backups/ dirs
#    --skip-builds   exclude .fly-build/ and tmp_root/
# ══════════════════════════════════════════════════════

# ── ARGS ─────────────────────────────────────────────
OLD="${1:-1,250}"
NEW="${2:-1,750}"
DRY=false
LIVE=false
SKIP_BACKUPS=false
SKIP_BUILDS=false

for arg in "$@"; do
  case $arg in
    --dry)          DRY=true ;;
    --live)         LIVE=true ;;
    --skip-backups) SKIP_BACKUPS=true ;;
    --skip-builds)  SKIP_BUILDS=true ;;
  esac
done

# ── EXTENSIONS TO SCAN ───────────────────────────────
EXTENSIONS=("html" "js" "css" "txt" "md" "json")

# ── COLORS ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; DIM='\033[2m'; RESET='\033[0m'

echo ""
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  TSM STRING FIX${RESET}"
echo -e "  Find:    ${RED}\$$OLD${RESET}"
echo -e "  Replace: ${GREEN}\$$NEW${RESET}"
if $DRY;          then echo -e "  Mode:    ${YELLOW}DRY RUN — no files will be changed${RESET}"; fi
if $SKIP_BACKUPS; then echo -e "  ${DIM}Skipping: _backup_* / backups/${RESET}"; fi
if $SKIP_BUILDS;  then echo -e "  ${DIM}Skipping: .fly-build/ / tmp_root/${RESET}"; fi
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo ""

# ── BUILD FIND COMMAND ────────────────────────────────
FIND_CMD=(find .)

# Exclusions
FIND_CMD+=(\( -path "*/.git/*" -prune \) -o)
FIND_CMD+=(\( -path "*/node_modules/*" -prune \) -o)
if $SKIP_BACKUPS; then
  FIND_CMD+=(\( -path "./_backup*" -prune \) -o)
  FIND_CMD+=(\( -path "./backups/*" -prune \) -o)
fi
if $SKIP_BUILDS; then
  FIND_CMD+=(\( -path "./.fly-build/*" -prune \) -o)
  FIND_CMD+=(\( -path "./tmp_root/*" -prune \) -o)
fi

# File type filter
EXT_ARGS=()
for i in "${!EXTENSIONS[@]}"; do
  if [ $i -gt 0 ]; then EXT_ARGS+=(-o); fi
  EXT_ARGS+=(-name "*.${EXTENSIONS[$i]}")
done
FIND_CMD+=(\( "${EXT_ARGS[@]}" \) -print)

# ── SCAN ─────────────────────────────────────────────
echo -e "▸ SCANNING ..."
echo ""

MATCHES=()
TOTAL_HITS=0

while IFS= read -r file; do
  if grep -q "$OLD" "$file" 2>/dev/null; then
    COUNT=$(grep -c "$OLD" "$file" 2>/dev/null || echo 0)
    MATCHES+=("$file")
    TOTAL_HITS=$((TOTAL_HITS + COUNT))
    echo -e "  ${YELLOW}FOUND${RESET}  [${COUNT} hit(s)]  ${DIM}$file${RESET}"
    grep -n "$OLD" "$file" | head -5 | while IFS= read -r line; do
      echo -e "         ${DIM}└─ $line${RESET}"
    done
    echo ""
  fi
done < <("${FIND_CMD[@]}" 2>/dev/null)

TOTAL_FILES=${#MATCHES[@]}

# ── SUMMARY ──────────────────────────────────────────
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
if [ "$TOTAL_FILES" -eq 0 ]; then
  echo -e "  ${GREEN}✓ No occurrences of \$$OLD found. Nothing to fix.${RESET}"
  echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
  echo ""
  exit 0
fi
echo -e "  Found ${RED}\$$OLD${RESET} in ${YELLOW}$TOTAL_FILES file(s)${RESET} — ${YELLOW}$TOTAL_HITS total hit(s)${RESET}"
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo ""

# ── DRY RUN STOPS HERE ────────────────────────────────
if $DRY; then
  echo -e "  ${YELLOW}DRY RUN — no changes made.${RESET}"
  echo -e "  Re-run without --dry to apply fixes."
  echo ""
  exit 0
fi

# ── CONFIRM ──────────────────────────────────────────
if ! $LIVE; then
  read -p "  Apply fix? Replace all \$$OLD → \$$NEW? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "  ${YELLOW}Aborted. No files changed.${RESET}"
    exit 0
  fi
fi

echo ""
echo -e "▸ APPLYING FIX ..."
echo ""

# ── APPLY ────────────────────────────────────────────
FIXED=0
for file in "${MATCHES[@]}"; do
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "s/$OLD/$NEW/g" "$file"
  else
    sed -i '' "s/$OLD/$NEW/g" "$file"
  fi
  echo -e "  ${GREEN}FIXED${RESET}  $file"
  ((FIXED++))
done

# ── DONE ─────────────────────────────────────────────
echo ""
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}✓ Done. Fixed $FIXED file(s) — $TOTAL_HITS replacement(s).${RESET}"
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo ""
echo -e "▸ ${CYAN}COMMIT:${RESET}"
echo -e "  git add -A"
echo -e "  git commit -m \"fix: update pricing \$$OLD → \$$NEW across suite\""
echo -e "  git push"
echo ""
