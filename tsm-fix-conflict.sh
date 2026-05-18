#!/usr/bin/env bash
# ============================================================
#  TSM Conflict Fix — resolves rebase conflicts by keeping
#  YOUR local (Codespace) version of every conflicted file.
#  Run this ONCE, then re-run tsm-push.sh
# ============================================================

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
log()  { echo -e "${CYAN}▸${RESET} $*"; }
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
err()  { echo -e "${RED}✗${RESET} $*"; }

echo -e "${BOLD}  TSM Conflict Resolver${RESET}"
echo "  Strategy: keep YOUR Codespace version of every conflict"
echo ""

# Find all conflicted files
CONFLICTS=$(git diff --name-only --diff-filter=U 2>/dev/null)

if [[ -z "$CONFLICTS" ]]; then
  log "No conflicts detected — checking rebase state..."
  if [[ -d "$(git rev-parse --git-dir)/rebase-merge" ]] || \
     [[ -d "$(git rev-parse --git-dir)/rebase-apply" ]]; then
    log "Rebase still in progress — aborting cleanly..."
    git rebase --abort
    ok "Rebase aborted. Your files are untouched."
    echo ""
    echo "  Now run:  bash tsm-push.sh"
  else
    ok "Nothing to fix. Run: bash tsm-push.sh"
  fi
  exit 0
fi

echo "  Conflicted files:"
while IFS= read -r f; do
  echo "    • $f"
done <<< "$CONFLICTS"
echo ""

# Keep OUR (Codespace) version for every conflict
while IFS= read -r file; do
  log "Keeping our version: ${file}"
  git checkout --ours -- "$file"
  git add "$file"
  ok "Resolved: ${file}"
done <<< "$CONFLICTS"

# Continue the rebase
echo ""
log "Continuing rebase..."
GIT_EDITOR=true git rebase --continue 2>&1 || {
  # If nothing left to commit, skip
  git rebase --skip 2>/dev/null || true
}

ok "Conflict resolved. Now run:  bash tsm-push.sh"
