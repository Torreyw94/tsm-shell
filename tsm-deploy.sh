#!/usr/bin/env bash
# ============================================================
#  tsm-deploy.sh
#  Commit all tracked + untracked files (skip .bak / .bak.*)
#  Wire all HTML files into suite indexes
#  Deploy to Fly.io
#
#  Usage:
#    chmod +x tsm-deploy.sh && ./tsm-deploy.sh
#    ./tsm-deploy.sh "optional commit message"
# ============================================================
set -euo pipefail

# ── Config ──────────────────────────────────────────────────
FLY_APP="tsm-shell"
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || pwd)"
COMMIT_MSG="${1:-"chore: auto-commit + deploy $(date '+%Y-%m-%d %H:%M')"}"
SKIP_PATTERN='\.bak\(\.\|$\)\|\.bak\.[a-zA-Z0-9._-]*'   # matches .bak and .bak.*

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m';  BOLD='\033[1m';     RESET='\033[0m'

banner() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()     { echo -e "${GREEN}  ✓ $1${RESET}"; }
warn()   { echo -e "${YELLOW}  ⚠ $1${RESET}"; }
err()    { echo -e "${RED}  ✗ $1${RESET}"; }
info()   { echo -e "  → $1"; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║   TSM Shell · Commit + Wire + Deploy             ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${RESET}"
info "Repo root : $REPO_ROOT"
info "Fly app   : $FLY_APP"
info "Message   : $COMMIT_MSG"

cd "$REPO_ROOT"

# ── 1. Verify tools ──────────────────────────────────────────
banner "STEP 1 · Checking tools"
for tool in git node; do
  command -v "$tool" &>/dev/null && ok "$tool found" || { err "$tool not found"; exit 1; }
done
FLY=$(command -v flyctl 2>/dev/null || command -v fly 2>/dev/null || true)
if [[ -z "$FLY" ]]; then
  warn "flyctl not found — deploy step will be skipped"
  SKIP_DEPLOY=1
else
  ok "flyctl found"
  SKIP_DEPLOY=0
fi

# ── 2. Remove stray .bak files from git index (if tracked) ───
banner "STEP 2 · Untracking .bak files"
BAK_TRACKED=$(git ls-files | grep -E '\.bak(\.[a-zA-Z0-9._-]+)?$' || true)
if [[ -n "$BAK_TRACKED" ]]; then
  echo "$BAK_TRACKED" | while read -r f; do
    git rm --cached --ignore-unmatch "$f" --quiet && warn "Untracked from git: $f"
  done
else
  ok "No .bak files in git index"
fi

# Ensure .gitignore excludes them going forward
if ! grep -q "^*.bak" "$REPO_ROOT/.gitignore" 2>/dev/null; then
  echo "*.bak"       >> "$REPO_ROOT/.gitignore"
  echo "*.bak.*"     >> "$REPO_ROOT/.gitignore"
  ok "Added *.bak / *.bak.* to .gitignore"
fi

# ── 3. Wire HTML files into suite index files ────────────────
banner "STEP 3 · Wiring HTML files into suite indexes"
node - <<'NODEWIRE'
const fs   = require('fs');
const path = require('path');

const SUITES = [
  { dir: 'html/finops-suite',        index: 'html/finops-suite/suite-index.html',       title: 'FinOps Suite' },
  { dir: 'html/construction-suite',  index: 'html/construction-suite/suite-index.html', title: 'Construction Suite' },
  { dir: 'html/tsm-insurance',       index: 'html/tsm-insurance/suite-index.html',      title: 'Insurance Suite' },
];

// Files to exclude from suite indexes
const EXCLUDE = [
  'suite-index.html','tsm-insurance-suite-index.html','index.html',
  /\.bak(\.[a-zA-Z0-9._-]+)?$/,
  /^assets\//,/^docs\//,/^wip\//,/^wip-billing\//,
  /^showcase\//,/^financial\//,/^construction-docs\//,
  /^finops-showcase\//,/^finops-main-strategist\//,/^finops-presentation\//,
  /^v[0-9]+/,
];

function shouldExclude(name) {
  return EXCLUDE.some(e => e instanceof RegExp ? e.test(name) : e === name);
}

function friendlyName(file) {
  return file.replace('.html','').replace(/-/g,' ').replace(/_/g,' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}

function iconFor(name) {
  const n = name.toLowerCase();
  if (n.includes('command'))     return '⚡';
  if (n.includes('compliance'))  return '🛡';
  if (n.includes('doc'))         return '📄';
  if (n.includes('tax'))         return '💰';
  if (n.includes('financial'))   return '📊';
  if (n.includes('invoice') || n.includes('billing')) return '🧾';
  if (n.includes('legal'))       return '⚖';
  if (n.includes('present'))     return '📽';
  if (n.includes('intel') || n.includes('brain')) return '🔍';
  if (n.includes('az-ins') || n.includes('insurance')) return '🌵';
  if (n.includes('agent'))       return '👥';
  if (n.includes('ce-') || n.includes('study')) return '🎓';
  if (n.includes('dme'))         return '🏥';
  if (n.includes('zero'))        return '🔐';
  if (n.includes('showcase'))    return '🖼';
  if (n.includes('audit'))       return '🔎';
  if (n.includes('permit') || n.includes('proposal')) return '📋';
  if (n.includes('hub'))         return '🏗';
  if (n.includes('staff') || n.includes('interview')) return '🧑‍💼';
  if (n.includes('pitch'))       return '🎯';
  if (n.includes('how-to'))      return '📖';
  if (n.includes('pc-') || n.includes('p&c')) return '🏠';
  return '📁';
}

for (const suite of SUITES) {
  const absDir   = path.resolve(suite.dir);
  const absIndex = path.resolve(suite.index);
  if (!fs.existsSync(absDir)) { console.log(`  ⚠ Dir not found: ${suite.dir}`); continue; }

  const files = fs.readdirSync(absDir)
    .filter(f => f.endsWith('.html') && !shouldExclude(f))
    .sort();

  const cards = files.map(f => {
    const icon = iconFor(f);
    const label = friendlyName(f);
    return `      <a class="suite-card" href="${f}">
        <span class="sc-icon">${icon}</span>
        <span class="sc-name">${label}</span>
        <span class="sc-arrow">→</span>
      </a>`;
  }).join('\n');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>TSM · ${suite.title}</title>
<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet"/>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#0b0b0b;--bg2:#111;--bg3:#161616;--border:#222;--text:#ccc;--dim:#555;--gold:#f5c518;--sans:'Inter',sans-serif;--mono:'JetBrains Mono',monospace}
body{background:var(--bg);color:var(--text);font-family:var(--sans);min-height:100vh;padding:32px 24px}
header{display:flex;align-items:center;justify-content:space-between;margin-bottom:28px;flex-wrap:wrap;gap:10px}
.brand{color:var(--gold);font-family:var(--mono);font-size:13px;font-weight:700;letter-spacing:.12em}
.brand-sub{color:var(--dim);font-size:10px;letter-spacing:.1em;margin-top:2px;font-family:var(--mono)}
.back{color:var(--dim);font-size:11px;text-decoration:none;border:1px solid var(--border);padding:5px 12px;border-radius:3px;transition:color .15s,border-color .15s}
.back:hover{color:var(--gold);border-color:var(--gold)}
h1{color:#f0f0f0;font-size:20px;font-weight:700;margin-bottom:4px}
.sub{color:var(--dim);font-size:11px;margin-bottom:24px;font-family:var(--mono)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px}
.suite-card{
  background:var(--bg2);border:1px solid var(--border);border-radius:5px;
  padding:14px 16px;display:flex;align-items:center;gap:10px;
  text-decoration:none;color:var(--text);font-size:12px;font-weight:500;
  transition:border-color .15s,background .15s;
}
.suite-card:hover{border-color:var(--gold);background:#161400}
.sc-icon{font-size:18px;flex-shrink:0}
.sc-name{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.sc-arrow{color:var(--dim);font-size:12px;flex-shrink:0;transition:color .15s}
.suite-card:hover .sc-arrow{color:var(--gold)}
.count{color:var(--dim);font-family:var(--mono);font-size:11px}
</style>
</head>
<body>
<header>
  <div>
    <div class="brand">🌐 TSM SHELL · ${suite.title.toUpperCase()}</div>
    <div class="brand-sub">AUTO-GENERATED · ${new Date().toISOString().slice(0,10)}</div>
  </div>
  <a class="back" href="../index.html">← Back to Hub</a>
</header>
<h1>${suite.title}</h1>
<div class="sub">${files.length} modules · click to open</div>
<div class="grid">
${cards}
</div>
</body>
</html>`;

  fs.writeFileSync(absIndex, html, 'utf8');
  console.log(`  ✓ Wired ${files.length} files → ${suite.index}`);
}
NODEWIRE
ok "Suite indexes rebuilt"

# ── 4. Git add + commit ──────────────────────────────────────
banner "STEP 4 · Git commit"
git -C "$REPO_ROOT" add --all
# Remove any .bak files that snuck into the staging area (|| true so grep exit-1 doesn't kill script)
git -C "$REPO_ROOT" diff --cached --name-only \
  | { grep -E '\.bak(\.[a-zA-Z0-9._-]+)?$' || true; } \
  | xargs -r git -C "$REPO_ROOT" rm --cached --ignore-unmatch --quiet --
STAGED=$(git -C "$REPO_ROOT" diff --cached --name-only | wc -l | tr -d ' ')
if [[ "$STAGED" -eq 0 ]]; then
  warn "Nothing to commit — working tree clean"
else
  git -C "$REPO_ROOT" commit -m "$COMMIT_MSG" || warn "Commit failed (possibly nothing new after bak cleanup)"
  ok "Committed $STAGED files: $COMMIT_MSG"
fi

# ── 5. Git push ──────────────────────────────────────────────
banner "STEP 5 · Git push"
REMOTE=$(git -C "$REPO_ROOT" remote | head -1 || true)
if [[ -n "$REMOTE" ]]; then
  BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)
  git -C "$REPO_ROOT" push "$REMOTE" "$BRANCH"
  ok "Pushed to $REMOTE/$BRANCH"
else
  warn "No git remote configured — skipping push"
fi

# ── 6. Fly deploy ────────────────────────────────────────────
banner "STEP 6 · Fly.io deploy"
if [[ "${SKIP_DEPLOY:-0}" -eq 1 ]]; then
  warn "Skipping — flyctl not installed"
else
  $FLY deploy --app "$FLY_APP" --ha=false
  ok "Deployed → https://${FLY_APP}.fly.dev"
fi

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗"
echo    "║  ✓ ALL DONE                                      ║"
echo -e "╚══════════════════════════════════════════════════╝${RESET}"
echo -e "  Live: ${CYAN}https://${FLY_APP}.fly.dev${RESET}"
echo ""
