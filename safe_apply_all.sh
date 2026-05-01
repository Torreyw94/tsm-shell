#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/workspaces/tsm-shell}"
cd "$ROOT"

echo "== SAFE APPLY ALL =="

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/safe_apply_all

# 0) Snapshot important files
for f in server.js html/honor-portal/index.html; do
  [ -f "$f" ] && cp -f "$f" "backups/safe_apply_all/$(basename "$f").$STAMP.bak" || true
done

echo "== 1) CHECK SERVER SYNTAX =="
if node -c server.js >/dev/null 2>&1; then
  echo "server.js syntax OK"
else
  echo "server.js syntax BROKEN -> restoring committed version"
  git restore --source=HEAD -- server.js
fi

echo "== 2) VERIFY RESTORED SERVER =="
node -c server.js

echo "== 3) REMOVE ONLY COMMON TEMP/DEBUG ARTIFACTS FROM TRACKING VIEW =="
find html/honor-portal -maxdepth 1 -type f \
  \( -name '*.bak.*' -o -name '*.cleanbak.*' -o -name '*.restorebak.*' -o -name '*.stablebak.*' -o -name '*.unhidebak.*' -o -name '*.directbak.*' -o -name '*.globalfix.*' -o -name '*.warroomfix.*' -o -name '*.containerfix.*' -o -name '*.cleanfinal.*' -o -name '*.cardsbak.*' -o -name '*.fullcmd.*' -o -name '*.forceclean.*' -o -name '*.cleanrender.*' \) \
  -print -delete || true

echo "== 4) GIT STATUS BEFORE COMMIT =="
git status --short || true

echo "== 5) COMMIT ONLY TRACKED CHANGES IF ANY =="
git add server.js html/honor-portal/index.html 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "Safe apply: restore backend syntax and preserve Dee command UI"
else
  echo "No tracked changes to commit"
fi

echo "== 6) SYNC WITH REMOTE =="
git pull --rebase origin main || {
  echo "Rebase failed. Aborting rebase and doing a safe pull."
  git rebase --abort || true
  git pull --no-rebase origin main
}

echo "== 7) PUSH =="
git push origin main

echo "== 8) FINAL SYNTAX GATE =="
node -c server.js

echo "== 9) DEPLOY =="
fly deploy

echo "== 10) SMOKE TESTS =="
echo "-- Dee dashboard --"
curl -sS -X POST https://tsm-shell.fly.dev/api/honor/dee/dashboard \
  -H "Content-Type: application/json" \
  -d '{"system":"HonorHealth"}' | head -c 700; echo

echo "-- Strategist action --"
curl -sS -X POST https://tsm-shell.fly.dev/api/strategist/hc/dee-action \
  -H "Content-Type: application/json" \
  -d '{"system":"HonorHealth","selectedOffice":"Scottsdale - Shea","prompt":"denial reduction plan"}' | head -c 700; echo

echo "-- Honor portal HTML --"
curl -I https://tsm-shell.fly.dev/html/honor-portal/?v=safe-${STAMP}

echo "== DONE =="
