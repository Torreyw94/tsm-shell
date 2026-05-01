#!/bin/bash
# ════════════════════════════════════════════════════════
#  TSM SHELL — MASTER WIRE + DEPLOY
#  Puts everything into tsm-shell/html/. One machine only.
#  Run from: /workspaces/tsm-shell
# ════════════════════════════════════════════════════════

set -e
BASE="/workspaces/tsm-shell"
HTML="$BASE/html"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TSM SHELL WIRE + DEPLOY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── STEP 1: Copy tmp_root stubs into html/ (only if html/ version is missing/stub) ──
echo "▸ Step 1: Wiring tmp_root apps into html/..."
DEPLOY_ROOT="$BASE/tmp_root/tsm-deploy"

for app_dir in "$DEPLOY_ROOT"/*/; do
  app_name=$(basename "$app_dir")
  # Strip tsm- prefix to match html/ directory names
  html_name="${app_name#tsm-}"
  target="$HTML/$html_name"
  src_file="$app_dir/public/index.html"

  if [ ! -f "$src_file" ]; then
    echo "  ⚠ No public/index.html in $app_name — skipping"
    continue
  fi

  # Check if it's a real app (>5KB) or a stub (<2KB)
  src_size=$(wc -c < "$src_file")

  if [ ! -d "$target" ]; then
    echo "  + Creating $target"
    mkdir -p "$target"
    cp "$src_file" "$target/index.html"
  elif [ "$src_size" -gt 2048 ]; then
    # Source is a real app, not a stub — copy it
    echo "  ↻ Updating $target (src is real app)"
    cp "$src_file" "$target/index.html"
  else
    echo "  ✓ $target exists (stub skipped)"
  fi
done

# ── STEP 2: Create music app ──
echo ""
echo "▸ Step 2: Installing Music Command app..."
mkdir -p "$HTML/music"

# Only overwrite if missing or stub
MUSIC_FILE="$HTML/music/index.html"
if [ ! -f "$MUSIC_FILE" ] || [ $(wc -c < "$MUSIC_FILE") -lt 5000 ]; then
  echo "  + Writing music/index.html"
  # The music app HTML should be dropped here by the user (see instructions below)
  cat > "$MUSIC_FILE" << 'MUSIC_PLACEHOLDER'
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>TSM · Music Command</title></head>
<body style="background:#05080f;color:#c8c0e8;font-family:monospace;padding:40px;text-align:center">
  <h2 style="color:#a855f7">♪ TSM Music Command</h2>
  <p style="margin-top:16px;color:#5a4a7a">Drop music/index.html here from the Claude output.</p>
  <p style="margin-top:8px;font-size:11px;color:#2e1e4a">Path: /workspaces/tsm-shell/html/music/index.html</p>
</body></html>
MUSIC_PLACEHOLDER
  echo "  ⚠ Placeholder written. Replace with full music app (see below)."
else
  echo "  ✓ music/index.html already exists"
fi

# ── STEP 3: Fix root index.html ──
echo ""
echo "▸ Step 3: Checking root hub..."
ROOT_INDEX="$HTML/index.html"
root_size=$(wc -c < "$ROOT_INDEX" 2>/dev/null || echo 0)
if [ "$root_size" -lt 3000 ]; then
  echo "  ⚠ Root index.html is small ($root_size bytes) — needs the new hub."
  echo "  → Copy the new hub index.html from Claude output to: $ROOT_INDEX"
else
  echo "  ✓ Root index.html looks good ($root_size bytes)"
fi

# ── STEP 4: Scan and report all apps ──
echo ""
echo "▸ Step 4: App inventory..."
total=0
for d in "$HTML"/*/; do
  name=$(basename "$d")
  f="$d/index.html"
  if [ -f "$f" ]; then
    sz=$(wc -c < "$f")
    status="✓"
    [ "$sz" -lt 500 ] && status="⚠ stub"
    printf "  %s %-30s %s bytes\n" "$status" "$name" "$sz"
    total=$((total+1))
  fi
done
echo ""
echo "  Total: $total apps in html/"

# ── STEP 5: Verify server.js serves html/ ──
echo ""
echo "▸ Step 5: Checking server config..."
SERVER="$BASE/server.js"
if [ -f "$SERVER" ]; then
  if grep -q "express.static" "$SERVER" && grep -q "html" "$SERVER"; then
    echo "  ✓ server.js serves html/ directory"
  else
    echo "  ⚠ server.js may not be serving html/ — check manually"
  fi
else
  echo "  ⚠ server.js not found at expected path"
fi

# ── STEP 6: Deploy tsm-shell ──
echo ""
echo "▸ Step 6: Deploying tsm-shell to Fly.io..."
cd "$BASE"

# Quick syntax check
if [ -f "$BASE/fly.toml" ]; then
  echo "  ✓ fly.toml found"
  fly deploy --ha=false
  echo ""
  echo "  ✓ Deploy complete!"
  echo "  → https://tsm-shell.fly.dev"
  echo "  → https://tsm-shell.fly.dev/html/music/"
  echo "  → https://tsm-shell.fly.dev/html/honor-portal/"
  echo "  → https://tsm-shell.fly.dev/html/hc-strategist/"
else
  echo "  ✗ fly.toml not found at $BASE"
  echo "  Run from: /workspaces/tsm-shell"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DONE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NEXT STEPS:"
echo "  1. Copy music app:   cp <claude-output>/music-index.html $HTML/music/index.html"
echo "  2. Copy new hub:     cp <claude-output>/index.html $HTML/index.html"
echo "  3. Run this script:  bash tsm-wire-deploy.sh"
echo ""
