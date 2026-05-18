#!/usr/bin/env bash
# ============================================================
#  TSM GitHub Sync — Codespace → tsm-shell repo
#  Pushes HTML files to their correct directory in GitHub.
#  Usage:  bash tsm-push.sh [optional: "your commit message"]
# ============================================================

set -euo pipefail

# ─── CONFIG ────────────────────────────────────────────────
REPO_OWNER="Torreyw94"
REPO_NAME="tsm-shell"
BRANCH="main"
REMOTE="origin"
# ───────────────────────────────────────────────────────────

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}▸${RESET} $*"; }
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
err()  { echo -e "${RED}✗${RESET} $*"; }
hr()   { echo -e "${CYAN}──────────────────────────────────────────${RESET}"; }

hr
echo -e "${BOLD}  TSM GitHub Sync Script${RESET}"
echo -e "  Repo: ${CYAN}${REPO_OWNER}/${REPO_NAME}${RESET} → branch: ${CYAN}${BRANCH}${RESET}"
hr

# ─── 1. FIND REPO ROOT ─────────────────────────────────────
# Works whether you're in the repo root or a subdirectory
if git rev-parse --show-toplevel &>/dev/null; then
  REPO_ROOT=$(git rev-parse --show-toplevel)
  ok "Git repo root: ${REPO_ROOT}"
else
  err "Not inside a git repository. Run this script from within your tsm-shell Codespace."
  exit 1
fi

cd "$REPO_ROOT"

# ─── 2. VERIFY REMOTE ──────────────────────────────────────
REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null || echo "")
if [[ -z "$REMOTE_URL" ]]; then
  err "No remote named '${REMOTE}' found."
  echo "   Run: git remote add origin https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
  exit 1
fi
ok "Remote: ${REMOTE_URL}"

# ─── 3. CHECK FOR UNCOMMITTED CHANGES ──────────────────────
CHANGED_HTML=$(git status --short | grep '\.html' || true)
ALL_CHANGED=$(git status --short | grep -v '^??' || true)  # tracked changes only

if [[ -z "$ALL_CHANGED" ]] && [[ -z "$(git status --short)" ]]; then
  warn "Nothing to commit — working tree is clean."
  echo "   If you have new files, make sure they're saved in the Codespace."
  exit 0
fi

# ─── 4. SHOW WHAT WILL BE PUSHED ───────────────────────────
hr
echo -e "${BOLD}  Files detected:${RESET}"
hr

# Show all changed HTML files with their target paths
HTML_COUNT=0
OTHER_COUNT=0

while IFS= read -r line; do
  STATUS="${line:0:2}"
  FILE="${line:3}"
  EXT="${FILE##*.}"

  if [[ "$EXT" == "html" ]]; then
    echo -e "  ${GREEN}HTML${RESET}  ${STATUS}  ${FILE}"
    ((HTML_COUNT++)) || true
  else
    echo -e "  ${YELLOW}FILE${RESET}  ${STATUS}  ${FILE}"
    ((OTHER_COUNT++)) || true
  fi
done < <(git status --short)

echo ""
echo -e "  ${GREEN}${HTML_COUNT} HTML${RESET} file(s)  |  ${YELLOW}${OTHER_COUNT}${RESET} other file(s)"
hr

# ─── 5. PULL LATEST FIRST (avoid conflicts) ────────────────
log "Pulling latest from ${REMOTE}/${BRANCH}..."
if git pull "$REMOTE" "$BRANCH" --rebase --autostash 2>&1 | tail -3; then
  ok "Up to date with remote"
else
  err "Pull/rebase failed. Resolve conflicts then re-run."
  exit 1
fi

# ─── 6. STAGE ALL CHANGES ──────────────────────────────────
log "Staging all changes..."
git add -A
ok "All changes staged"

# ─── 7. COMMIT MESSAGE ─────────────────────────────────────
if [[ $# -ge 1 && -n "${1:-}" ]]; then
  COMMIT_MSG="$1"
else
  # Auto-generate a descriptive commit message
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
  HTML_LIST=$(git diff --cached --name-only | grep '\.html' | xargs -I{} basename {} | tr '\n' ', ' | sed 's/,$//')
  if [[ -n "$HTML_LIST" ]]; then
    COMMIT_MSG="[TSM] Update HTML: ${HTML_LIST} — ${TIMESTAMP}"
  else
    COMMIT_MSG="[TSM] Sync Codespace changes — ${TIMESTAMP}"
  fi
fi

log "Commit message: \"${COMMIT_MSG}\""

git commit -m "$COMMIT_MSG"
ok "Committed"

# ─── 8. PUSH ───────────────────────────────────────────────
log "Pushing to ${REMOTE}/${BRANCH}..."
if git push "$REMOTE" "$BRANCH"; then
  ok "Push successful!"
else
  err "Push failed. You may need to authenticate:"
  echo ""
  echo "   Option A — HTTPS with token:"
  echo "     git remote set-url origin https://<TOKEN>@github.com/${REPO_OWNER}/${REPO_NAME}.git"
  echo ""
  echo "   Option B — SSH:"
  echo "     git remote set-url origin git@github.com:${REPO_OWNER}/${REPO_NAME}.git"
  echo ""
  echo "   Option C — GitHub CLI (easiest):"
  echo "     gh auth login"
  echo "     gh repo sync"
  exit 1
fi

# ─── 9. SUMMARY ────────────────────────────────────────────
hr
echo -e "${BOLD}${GREEN}  ✓ All done!${RESET}"
echo -e "  ${CYAN}https://github.com/${REPO_OWNER}/${REPO_NAME}/tree/${BRANCH}${RESET}"
hr
echo ""
