#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  tsm-syntax-audit.sh
#  Audits and auto-repairs JS syntax errors in TSM portal HTML files.
#  Companion to tsm-fly-deploy-all.sh
#
#  Usage:
#    bash tsm-syntax-audit.sh [--fix] [--file path/to/file.html] [--dir /path]
#
#  Options:
#    --fix              Auto-patch fixable errors (backs up originals as .bak)
#    --file FILE        Audit a single HTML file
#    --dir DIR          Audit all HTML files in a directory (recursive)
#    --report FILE      Write JSON report to file (default: /workspaces/tsm-shell/onclick-audit/report.json)
#    --no-color         Disable color output
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
CYN='\033[0;36m'; BLD='\033[1m'; RST='\033[0m'
info()  { echo -e "${CYN}[INFO]${RST}  $*"; }
ok()    { echo -e "${GRN}[OK]${RST}    $*"; }
warn()  { echo -e "${YLW}[WARN]${RST}  $*"; }
err()   { echo -e "${RED}[ERR]${RST}   $*"; }
hdr()   { echo -e "\n${BLD}${CYN}══ $* ══${RST}"; }

FIX=false; SINGLE_FILE=""; SCAN_DIR=""; REPORT_FILE="/workspaces/tsm-shell/onclick-audit/report.json"
for arg in "$@"; do
  case "$arg" in
    --fix)       FIX=true ;;
    --file)      shift; SINGLE_FILE="$1" ;;
    --dir)       shift; SCAN_DIR="$1" ;;
    --report)    shift; REPORT_FILE="$1" ;;
    --no-color)  RED=''; GRN=''; YLW=''; CYN=''; BLD=''; RST='' ;;
  esac
done

command -v node >/dev/null 2>&1 || { err "node is required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { err "python3 is required"; exit 1; }

mkdir -p "$(dirname "$REPORT_FILE")"

# ── COLLECT FILES ─────────────────────────────────────────────────────────────
declare -a HTML_FILES=()
if [[ -n "$SINGLE_FILE" ]]; then
  [[ -f "$SINGLE_FILE" ]] || { err "File not found: $SINGLE_FILE"; exit 1; }
  HTML_FILES=("$SINGLE_FILE")
elif [[ -n "$SCAN_DIR" ]]; then
  [[ -d "$SCAN_DIR" ]] || { err "Directory not found: $SCAN_DIR"; exit 1; }
  while IFS= read -r -d '' f; do HTML_FILES+=("$f"); done < <(find "$SCAN_DIR" -name "*.html" -print0)
else
  # Default: scan all known TSM source locations
  for loc in \
    /var/www /srv /root /workspaces/tsm-shell \
    /workspaces/tsm-shell/portals /workspaces/tsm-fly-export
  do
    [[ -d "$loc" ]] && while IFS= read -r -d '' f; do HTML_FILES+=("$f"); done < <(find "$loc" -name "*.html" -maxdepth 4 -print0 2>/dev/null) || true
  done
fi

total=${#HTML_FILES[@]}
hdr "TSM SYNTAX AUDIT — $total HTML files"
$FIX && warn "AUTO-FIX enabled — originals backed up as .bak"

PASS=0; FAIL=0; FIXED=0
declare -a REPORT_ENTRIES=()

# ── NODE AUDIT SCRIPT (inline) ─────────────────────────────────────────────
NODE_AUDITOR=$(cat << 'NODEEOF'
const fs = require('fs');
const file = process.argv[2];
let src;
try { src = fs.readFileSync(file, 'utf8'); } catch(e) { console.log(JSON.stringify({file,error:'read_error',details:e.message})); process.exit(2); }

const results = { file, scripts: [], errors: [], attrs: [] };

// 1. Audit inline <script> blocks
const scriptRe = /<script(?![^>]*\bsrc\b)[^>]*>([\s\S]*?)<\/script>/gi;
let m, idx = 0;
while ((m = scriptRe.exec(src)) !== null) {
  idx++;
  const code = m[1].trim();
  if (!code) continue;
  results.scripts.push(idx);
  try {
    new Function(code);
  } catch(e) {
    const htmlLine = src.slice(0, m.index).split('\n').length;
    // Find the JS line within the block
    const jsLines = m[1].split('\n');
    let jsLine = 0;
    // Try to get the specific line from the error message
    const lineMatch = e.stack && e.stack.match(/<anonymous>:(\d+)/);
    if (lineMatch) jsLine = parseInt(lineMatch[1]);
    results.errors.push({
      type: 'script_block',
      scriptIndex: idx,
      htmlLine,
      jsLine: jsLine || '?',
      message: e.message,
      // Snippet of surrounding code for context
      context: jsLines.slice(Math.max(0,(jsLine||1)-2), (jsLine||1)+2).join('\n').trim().slice(0,200)
    });
  }
}

// 2. Audit inline event handler attributes (onclick, onchange, etc.)
const attrRe = /\b(on\w+)="([^"]*)"/g;
while ((m = attrRe.exec(src)) !== null) {
  const attr = m[1], val = m[2];
  if (!val.trim()) continue;
  const htmlLine = src.slice(0, m.index).split('\n').length;
  try {
    new Function(val);
  } catch(e) {
    results.attrs.push({
      type: 'attr_handler',
      attr,
      htmlLine,
      value: val.slice(0, 120),
      message: e.message
    });
  }
}

// 3. Detect common patterns that will fail
const patterns = [
  { re: /onclick="[^"]*'[^']*'[^"]*'[^"]*"/, label: 'unescaped_quotes_in_onclick' },
  { re: /href="javascript:[^"]*"[^>]*onclick="/, label: 'href_js_plus_onclick' },
  { re: /on\w+="[^"]*\${/, label: 'template_literal_in_attr' },
  { re: /on\w+="[^"]*&quot;[^"]*&quot;/, label: 'html_encoded_quotes_in_handler' },
];
for (const { re, label } of patterns) {
  if (re.test(src)) results.attrs.push({ type: 'pattern_warning', label, message: 'Pattern detected: ' + label });
}

const hasErrors = results.errors.length > 0 || results.attrs.filter(a=>a.type==='attr_handler').length > 0;
console.log(JSON.stringify({ ...results, hasErrors, scriptsChecked: idx }));
process.exit(hasErrors ? 1 : 0);
NODEEOF
)

# ── PYTHON FIXER (inline) ──────────────────────────────────────────────────
PYTHON_FIXER=$(cat << 'PYEOF'
import re, sys, json

file = sys.argv[1]
with open(file, 'r', encoding='utf-8', errors='replace') as f:
    src = f.read()

orig = src
report = {'file': file, 'fixes': [], 'unfixable': []}

# Fix 1: Trailing commas in function calls inside onclick/on* attrs
# e.g. onclick="fn(a, b,)" -> onclick="fn(a, b)"
def fix_trailing_comma(m):
    val = m.group(2)
    fixed = re.sub(r',\s*\)', ')', val)
    if fixed != val:
        report['fixes'].append({'type': 'trailing_comma', 'attr': m.group(1), 'from': val[:80], 'to': fixed[:80]})
    return m.group(1) + '="' + fixed + '"'

src = re.sub(r'\b(on\w+)="([^"]*)"', fix_trailing_comma, src)

# Fix 2: Semicolon between multiple statements in attr handlers
# e.g. onclick="foo()bar()" -> onclick="foo();bar()"
def fix_missing_semi(m):
    val = m.group(2)
    # Insert semicolon between )( patterns
    fixed = re.sub(r'\)\s*([a-zA-Z_$])', r'); \1', val)
    if fixed != val:
        report['fixes'].append({'type': 'missing_semicolon', 'attr': m.group(1)})
    return m.group(1) + '="' + fixed + '"'

src = re.sub(r'\b(on\w+)="([^"]*)"', fix_missing_semi, src)

# Fix 3: Double-quoted strings inside double-quoted onclick handlers
# e.g. onclick="fn("arg")" -> onclick="fn('arg')"
def fix_inner_dquotes(m):
    attr, val = m.group(1), m.group(2)
    # If val contains " it would have broken the attribute already — look for &quot;
    fixed = val.replace('&quot;', "'")
    if fixed != val:
        report['fixes'].append({'type': 'html_encoded_dquotes', 'attr': attr})
    return attr + '="' + fixed + '"'

src = re.sub(r'\b(on\w+)="([^"]*)"', fix_inner_dquotes, src)

# Fix 4: Backtick template literals in HTML attrs (breaks some browsers/parsers)
def fix_backticks(m):
    attr, val = m.group(1), m.group(2)
    if '`' not in val:
        return m.group(0)
    # Convert `Hello ${name}` -> 'Hello '+name+''
    def convert_template(t):
        inner = t.group(1)
        parts = re.split(r'\$\{([^}]+)\}', inner)
        result = []
        for i, part in enumerate(parts):
            if i % 2 == 0:  # literal string
                result.append("'" + part.replace("'", "\\'") + "'")
            else:  # expression
                result.append(part.strip())
        return '+'.join(p for p in result if p != "''") or "''"
    fixed = re.sub(r'`([^`]*)`', convert_template, val)
    if fixed != val:
        report['fixes'].append({'type': 'backtick_template', 'attr': attr})
    return attr + '="' + fixed + '"'

src = re.sub(r'\b(on\w+)="([^"]*)"', fix_backticks, src)

# Fix 5: Common pattern — onclick inside href with mixed quotes
# <a href="url" onclick="fn('x')"> is OK but href="javascript:fn('x')" onclick="..." is risky
# Flag but don't auto-fix href+onclick combos

unfixable_patterns = [
    (r'<script[^>]*>[^<]*function[^(]*\([^)]*\)\s*\{[^}]*\}[^<]*</script>', 'nested_function_syntax'),
]
for pattern, label in unfixable_patterns:
    if re.search(pattern, src, re.DOTALL):
        report['unfixable'].append(label)

changed = src != orig
if changed:
    backup = file + '.bak'
    import shutil
    shutil.copy2(file, backup)
    with open(file, 'w', encoding='utf-8') as f:
        f.write(src)

report['changed'] = changed
report['fix_count'] = len(report['fixes'])
print(json.dumps(report))
PYEOF
)

# ── AUDIT EACH FILE ───────────────────────────────────────────────────────────
for html_file in "${HTML_FILES[@]}"; do
  echo -ne "  Checking: ${CYN}$(basename "$html_file")${RST}... "

  audit_json=$(echo "$NODE_AUDITOR" | node - "$html_file" 2>/dev/null || echo '{"hasErrors":true,"errors":[{"message":"node_execution_error"}],"attrs":[]}')
  has_errors=$(echo "$audit_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(str(d.get('hasErrors',True)).lower())" 2>/dev/null || echo "true")

  if [[ "$has_errors" == "false" ]]; then
    scripts_checked=$(echo "$audit_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('scriptsChecked',0))" 2>/dev/null || echo "?")
    echo -e "${GRN}PASS${RST} ($scripts_checked scripts)"
    ((PASS++)) || true
    REPORT_ENTRIES+=("{\"file\":\"$html_file\",\"status\":\"pass\"}")
  else
    echo -e "${RED}FAIL${RST}"
    ((FAIL++)) || true

    # Print error details
    echo "$audit_json" | python3 - << 'PRINTPY'
import sys, json
d = json.load(sys.stdin)
for e in d.get('errors', []):
    print(f"    [{e['type']}] Script #{e.get('scriptIndex','?')} line {e.get('htmlLine','?')}: {e['message']}")
    if e.get('context'):
        for ln in e['context'].split('\n')[:3]:
            print(f"      > {ln}")
for a in d.get('attrs', []):
    if a['type'] == 'attr_handler':
        print(f"    [{a['attr']}] line {a.get('htmlLine','?')}: {a['message']}")
        print(f"      value: {a.get('value','')[:100]}")
    elif a['type'] == 'pattern_warning':
        print(f"    [pattern] {a['label']}: {a['message']}")
PRINTPY

    if $FIX; then
      echo -ne "    Auto-fixing... "
      fix_json=$(echo "$PYTHON_FIXER" | python3 - "$html_file" 2>/dev/null || echo '{"changed":false,"fix_count":0,"fixes":[]}')
      changed=$(echo "$fix_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(str(d.get('changed',False)).lower())" 2>/dev/null || echo "false")
      fix_count=$(echo "$fix_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('fix_count',0))" 2>/dev/null || echo "0")

      if [[ "$changed" == "true" ]]; then
        echo -e "${GRN}$fix_count fixes applied${RST} (backup: $(basename "$html_file").bak)"
        ((FIXED++)) || true
        # Re-audit after fix
        reaudit=$(echo "$NODE_AUDITOR" | node - "$html_file" 2>/dev/null || echo '{"hasErrors":true}')
        still_broken=$(echo "$reaudit" | python3 -c "import sys,json; d=json.load(sys.stdin); print(str(d.get('hasErrors',True)).lower())" 2>/dev/null || echo "true")
        if [[ "$still_broken" == "false" ]]; then
          echo -e "    ${GRN}✓ All issues resolved after fix${RST}"
        else
          warn "    Some issues remain — manual review needed"
        fi
      else
        echo -e "${YLW}No auto-fixable issues${RST} — manual review required"
      fi
    fi

    REPORT_ENTRIES+=("{\"file\":\"$html_file\",\"status\":\"fail\"}")
  fi
done

# ── WRITE JSON REPORT ─────────────────────────────────────────────────────────
{
  echo "{"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"total\": $total,"
  echo "  \"pass\": $PASS,"
  echo "  \"fail\": $FAIL,"
  echo "  \"fixed\": $FIXED,"
  echo "  \"files\": ["
  for i in "${!REPORT_ENTRIES[@]}"; do
    [[ $i -lt $((${#REPORT_ENTRIES[@]}-1)) ]] && echo "    ${REPORT_ENTRIES[$i]}," || echo "    ${REPORT_ENTRIES[$i]}"
  done
  echo "  ]"
  echo "}"
} > "$REPORT_FILE"

# ── SUMMARY ───────────────────────────────────────────────────────────────────
hdr "AUDIT SUMMARY"
echo -e "  Files checked : $total"
echo -e "  ${GRN}PASS${RST}          : $PASS"
echo -e "  ${RED}FAIL${RST}          : $FAIL"
$FIX && echo -e "  ${CYN}AUTO-FIXED${RST}    : $FIXED"
echo -e "  Report        : $REPORT_FILE"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  if ! $FIX; then
    echo -e "  Run with ${CYN}--fix${RST} to attempt auto-repair:"
    echo -e "  ${CYN}bash tsm-syntax-audit.sh --fix${RST}"
  fi
  echo -e "  Then re-deploy: ${CYN}bash tsm-fly-deploy-all.sh --push${RST}"
fi
