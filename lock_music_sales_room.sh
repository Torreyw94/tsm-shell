#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/tsm-shell

echo "== 1) Ensure demo conductor exists =="
test -f html/music-command/demo-conductor.html || {
  echo "❌ Missing html/music-command/demo-conductor.html"
  exit 1
}

echo "== 2) Add a helper to create real prospect links =="
cat > create_music_sales_link.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

CLIENT="${1:-Music Prospect}"
HOURS="${2:-24}"

curl -s -X POST https://tsm-shell.fly.dev/api/music/demo/create \
  -H "Content-Type: application/json" \
  -d "{\"client\":\"${CLIENT}\",\"hours\":${HOURS}}" \
| python3 - <<'PY'
import sys, json
data=json.load(sys.stdin)
token=data["demo"]["token"]
base="https://tsm-shell.fly.dev"
print("\n✅ Prospect sales-room link:\n")
print(f"{base}/html/music-command/demo-conductor.html?demo_token={token}&v=sales")
print("\nApp link:")
print(base + data["links"]["app"])
print("\nPresentation link:")
print(base + data["links"]["presentation"])
PY
SH

chmod +x create_music_sales_link.sh

echo "== 3) Add README note so index stays clean and conductor is sales room =="
cat > html/music-command/README.md <<'MD'
# ZY Music Command Pages

## Sales Room
Use this for prospects and live demos:

`/html/music-command/demo-conductor.html?demo_token=REAL_TOKEN&v=sales`

Create a real token with:

```bash
./create_music_sales_link.sh "Prospect Name" 24
cat > fix_conductor_runtime_errors.sh <<'EOF'
#!/usr/bin/env bash
set -e

FILE="html/music-command/demo-conductor.html"
cp "$FILE" "$FILE.bak.$(date +%s)"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/demo-conductor.html")
html = p.read_text(encoding="utf-8", errors="ignore")

# Patch unsafe .textContent assignments
html = re.sub(
    r'(\w+)\.textContent\s*=',
    r'if(\1){\1.textContent =',
    html
)

# Close missing braces if inserted
html = html.replace(";;", ";}")

# Add safe helper if not present
if "function safeSetText" not in html:
    html = html.replace("</script>", """
function safeSetText(id, value){
  const el = document.getElementById(id);
  if (el) el.textContent = value;
}
</script>
""")

p.write_text(html, encoding="utf-8")
print("✅ Runtime null safety patch applied")
PY
