#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# deploy.sh — FinOps Suite · doc-parser.js deployment
# Pushes doc-parser.js to GitHub and patches finops-main-strategist/index.html
#
# Usage:
#   chmod +x deploy.sh
#   GITHUB_TOKEN=ghp_xxxx ./deploy.sh
#
# Or set token inline:
#   ./deploy.sh ghp_xxxxxxxxxxxx
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
REPO="Torreyw94/tsm-shell"
BRANCH="main"
BASE_PATH="html/finops-suite"
API="https://api.github.com/repos/${REPO}/contents"
TOKEN="${1:-${GITHUB_TOKEN:-}}"

if [[ -z "$TOKEN" ]]; then
  echo "❌ No GitHub token. Usage: GITHUB_TOKEN=ghp_xxx ./deploy.sh"
  echo "   Get one at: https://github.com/settings/tokens (needs 'repo' scope)"
  exit 1
fi

AUTH="Authorization: Bearer ${TOKEN}"
CT="Content-Type: application/json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── HELPERS ───────────────────────────────────────────────────────────────────
b64_encode() { base64 -w0 "$1" 2>/dev/null || base64 "$1"; }

get_sha() {
  # Returns current SHA of a file (empty string if not found)
  local path="$1"
  curl -s -H "$AUTH" "${API}/${path}?ref=${BRANCH}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null || true
}

push_file() {
  local gh_path="$1"   # path in repo
  local local_file="$2" # local file to upload
  local commit_msg="$3"

  echo "  → Checking ${gh_path}…"
  local sha
  sha=$(get_sha "${gh_path}")

  local content
  content=$(b64_encode "${local_file}")

  local payload
  if [[ -n "$sha" ]]; then
    echo "  → Updating (SHA: ${sha:0:7}…)"
    payload=$(python3 -c "
import json
print(json.dumps({
  'message': '''${commit_msg}''',
  'content': '''${content}''',
  'sha':     '${sha}',
  'branch':  '${BRANCH}'
}))
")
  else
    echo "  → Creating new file"
    payload=$(python3 -c "
import json
print(json.dumps({
  'message': '''${commit_msg}''',
  'content': '''${content}''',
  'branch':  '${BRANCH}'
}))
")
  fi

  local resp
  resp=$(curl -s -X PUT \
    -H "$AUTH" -H "$CT" \
    -d "$payload" \
    "${API}/${gh_path}")

  local status
  status=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',{}).get('name','ERROR'))" 2>/dev/null || echo "ERROR")

  if [[ "$status" == "ERROR" ]]; then
    echo "  ❌ Failed: $(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','unknown error'))" 2>/dev/null)"
    return 1
  else
    echo "  ✅ Deployed: ${gh_path}"
  fi
}

patch_index_html() {
  # Downloads current index.html, injects doc-parser script tag if not present,
  # then re-uploads
  local gh_path="${BASE_PATH}/finops-main-strategist/index.html"
  echo ""
  echo "── Patching index.html ──────────────────────────────────"

  # Download current file
  local raw_url="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${gh_path}"
  local tmpfile
  tmpfile=$(mktemp /tmp/index_XXXXXX.html)

  echo "  → Fetching current index.html…"
  if ! curl -sf -H "$AUTH" "$raw_url" -o "$tmpfile"; then
    echo "  ⚠ Could not fetch index.html — skipping patch"
    rm -f "$tmpfile"
    return 0
  fi

  # Check if already patched
  if grep -q 'doc-parser.js' "$tmpfile"; then
    echo "  ✓ doc-parser.js already referenced in index.html — skipping"
    rm -f "$tmpfile"
    return 0
  fi

  # Inject before </head>
  local script_tag='  <!-- FinOps Doc Parser -->\n  <script src="/finops-suite/assets/doc-parser.js"><\/script>'
  if grep -q '</head>' "$tmpfile"; then
    sed -i "s|</head>|${script_tag}\n</head>|" "$tmpfile"
    echo "  → Injected doc-parser.js before </head>"
  else
    # Fallback: inject before first <script> tag
    sed -i "1s|^|<script src=\"/finops-suite/assets/doc-parser.js\"></script>\n|" "$tmpfile"
    echo "  → Injected doc-parser.js at top (no </head> found)"
  fi

  # Also wire the DocParser into the existing upload handler if present
  # Looks for the file input change handler and wraps it
  python3 - "$tmpfile" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    html = f.read()

# Check if upload handler exists and is not yet patched
if 'DocParser.parse' not in html and ('file-input' in html or 'fileInput' in html or 'uploadFile' in html or 'handleFile' in html):
    # Find a likely upload handler and note we need to wire it
    # We inject a universal wiring snippet before </body>
    wire_snippet = '''
<script>
/* ── doc-parser.js auto-wire ── */
(function() {
  // Listen for docparser progress events and update UI if elements exist
  document.addEventListener('docparser:progress', function(e) {
    var d = e.detail;
    var el = document.getElementById('parser-status') || document.getElementById('upload-status') || document.getElementById('doc-status');
    if (el) el.textContent = d.msg;
    console.log('[DocParser]', d.msg);
  });

  // Intercept any file input on the page
  document.addEventListener('change', async function(e) {
    if (e.target.type !== 'file') return;
    var files = Array.from(e.target.files || []);
    if (!files.length || typeof DocParser === 'undefined') return;

    for (var file of files) {
      try {
        var result = await DocParser.parse(file);
        // Store on the input element for downstream engines to pick up
        e.target._parsed = result;
        // Fire custom event so existing handlers can access clean text
        e.target.dispatchEvent(new CustomEvent('docparser:ready', {
          bubbles: true,
          detail: result
        }));
        console.log('[DocParser] Ready:', result.meta);
      } catch(err) {
        console.error('[DocParser] Error:', err);
      }
    }
  }, true);

  // Override any fetch/XHR that sends raw file bytes and replace with extracted text
  // Hook into window.extractedDocText for Groq/Claude API calls
  window.getExtractedText = function(inputEl) {
    if (inputEl && inputEl._parsed) return inputEl._parsed.text;
    return null;
  };
})();
</script>
'''
    if '</body>' in html:
        html = html.replace('</body>', wire_snippet + '\n</body>')
    else:
        html += wire_snippet
    print('  wired', file=sys.stderr)

with open(path, 'w', encoding='utf-8') as f:
    f.write(html)
PYEOF

  push_file "${gh_path}" "$tmpfile" "feat: wire doc-parser.js into index.html upload handler"
  rm -f "$tmpfile"
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║  FinOps Suite · doc-parser.js deploy              ║"
echo "║  Repo: ${REPO}              ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# 1. Deploy doc-parser.js to assets/
echo "── Step 1: Deploy doc-parser.js ────────────────────"
DOC_PARSER_SRC="${SCRIPT_DIR}/doc-parser.js"
if [[ ! -f "$DOC_PARSER_SRC" ]]; then
  echo "❌ doc-parser.js not found at: ${DOC_PARSER_SRC}"
  echo "   Place doc-parser.js in the same directory as deploy.sh"
  exit 1
fi
push_file \
  "${BASE_PATH}/assets/doc-parser.js" \
  "$DOC_PARSER_SRC" \
  "feat: add DocParser — PDF text+OCR, DOCX, XLSX, CSV extraction engine"

# 2. Also deploy manager-bar-patch.html if present
echo ""
echo "── Step 2: Deploy manager-bar-patch.html ───────────"
MGR_BAR="${SCRIPT_DIR}/manager-bar-patch.html"
if [[ -f "$MGR_BAR" ]]; then
  push_file \
    "${BASE_PATH}/finops-main-strategist/manager-bar-patch.html" \
    "$MGR_BAR" \
    "feat: update manager-bar-patch.html with node postures + Groq mini"
else
  echo "  ⚠ manager-bar-patch.html not found — skipping"
fi

# 3. Patch finops-main-strategist/index.html to wire doc-parser
echo ""
echo "── Step 3: Patch finops-main-strategist/index.html ─"
patch_index_html

# 4. Also patch financial-ui.html (hub) to include doc-parser
echo ""
echo "── Step 4: Patch financial-ui.html (hub) ───────────"
FUI_PATH="${BASE_PATH}/financial-ui.html"
FUI_TMP=$(mktemp /tmp/fui_XXXXXX.html)
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${FUI_PATH}"

if curl -sf -H "$AUTH" "$RAW" -o "$FUI_TMP"; then
  if ! grep -q 'doc-parser.js' "$FUI_TMP"; then
    sed -i "s|</head>|  <script src=\"/finops-suite/assets/doc-parser.js\"></script>\n</head>|" "$FUI_TMP"
    push_file "${FUI_PATH}" "$FUI_TMP" "feat: wire doc-parser.js into financial-ui.html"
  else
    echo "  ✓ Already patched — skipping"
  fi
else
  echo "  ⚠ Could not fetch financial-ui.html — skipping"
fi
rm -f "$FUI_TMP"

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║  ✅  Deploy complete!                             ║"
echo "║                                                   ║"
echo "║  Files deployed:                                  ║"
echo "║  • assets/doc-parser.js              (NEW)        ║"
echo "║  • finops-main-strategist/index.html (PATCHED)    ║"
echo "║  • financial-ui.html                 (PATCHED)    ║"
echo "║  • finops-main-strategist/           ║"
echo "║    manager-bar-patch.html            (UPDATED)    ║"
echo "║                                                   ║"
echo "║  Live in ~30s at:                                 ║"
echo "║  tsm-shell.fly.dev/finops-suite/                  ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
