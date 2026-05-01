#!/bin/bash
# ══════════════════════════════════════════════════════
#  TSM PRICING FIX — $1,250 → $1,750
#  Run from the root of your tsm-shell repo:
#    bash fix-pricing.sh
# ══════════════════════════════════════════════════════

OLD="1,250"
NEW="1,750"
EXTENSIONS=("html" "js" "css" "txt" "md")

echo ""
echo "══════════════════════════════════════════════"
echo "  TSM PRICING FIX — \$$OLD → \$$NEW"
echo "══════════════════════════════════════════════"
echo ""

# ── BUILD EXTENSION PATTERN ──────────────────────────
FIND_ARGS=()
for i in "${!EXTENSIONS[@]}"; do
  if [ $i -gt 0 ]; then FIND_ARGS+=("-o"); fi
  FIND_ARGS+=("-name" "*.${EXTENSIONS[$i]}")
done

# ── SCAN FIRST (DRY RUN) ─────────────────────────────
echo "▸ SCANNING for \$$OLD ..."
echo ""

MATCHES=()
while IFS= read -r file; do
  COUNT=$(grep -c "$OLD" "$file" 2>/dev/null || true)
  if [ "$COUNT" -gt 0 ]; then
    MATCHES+=("$file")
    echo "  FOUND  [$COUNT hit(s)]  $file"
    grep -n "$OLD" "$file" | while read -r line; do
      echo "         └─ $line"
    done
    echo ""
  fi
done < <(find . \( "${FIND_ARGS[@]}" \) -not -path "*/node_modules/*" -not -path "*/.git/*")

# ── SUMMARY ──────────────────────────────────────────
TOTAL=${#MATCHES[@]}
if [ "$TOTAL" -eq 0 ]; then
  echo "  ✓ No occurrences of \$$OLD found. Nothing to fix."
  echo ""
  exit 0
fi

echo "══════════════════════════════════════════════"
echo "  Found \$$OLD in $TOTAL file(s)"
echo "══════════════════════════════════════════════"
echo ""

# ── CONFIRM ──────────────────────────────────────────
read -p "  Apply fix? Replace all \$$OLD → \$$NEW? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "  Aborted. No files changed."
  exit 0
fi

echo ""
echo "▸ APPLYING FIX ..."
echo ""

# ── APPLY (cross-platform: works on macOS + Linux) ───
FIXED=0
for file in "${MATCHES[@]}"; do
  if sed --version 2>/dev/null | grep -q GNU; then
    # Linux GNU sed
    sed -i "s/$OLD/$NEW/g" "$file"
  else
    # macOS BSD sed
    sed -i '' "s/$OLD/$NEW/g" "$file"
  fi
  echo "  FIXED  $file"
  ((FIXED++))
done

echo ""
echo "══════════════════════════════════════════════"
echo "  ✓ Done. Fixed $FIXED file(s)."
echo "══════════════════════════════════════════════"
echo ""
echo "▸ NEXT STEPS:"
echo "  git add -A"
echo "  git commit -m \"fix: update pricing \$$OLD → \$$NEW across suite\""
echo "  git push"
echo ""
