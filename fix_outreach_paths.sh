#!/usr/bin/env bash
set -e

FILE="outreach/outreach.js"

cp "$FILE" "$FILE.bak.$(date +%s)"

python3 <<'PY'
from pathlib import Path

p = Path("outreach/outreach.js")
text = p.read_text()

# Replace leads path with absolute relative to script
text = text.replace(
    "fs.readFileSync('./leads.json')",
    "fs.readFileSync(__dirname + '/leads.json')"
)

text = text.replace(
    "fs.writeFileSync('./leads.json'",
    "fs.writeFileSync(__dirname + '/leads.json'"
)

p.write_text(text)
print("✅ Fixed outreach pathing")
PY

