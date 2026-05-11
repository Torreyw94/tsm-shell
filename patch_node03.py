#!/usr/bin/env python3
"""
Patches financial-ui.html to point Node 03 at finops-main-strategist.html
Run from: /workspaces/tsm-shell
"""
import re, sys

path = "html/finops-suite/financial-ui.html"
old = "/finops-suite/finops-main-strategist/index.html"
new = "/finops-suite/finops-main-strategist.html"

with open(path, "r") as f:
    src = f.read()

count = src.count(old)
if count == 0:
    print(f"[!] Pattern not found — already patched or path changed.")
    sys.exit(0)

patched = src.replace(old, new)

with open(path, "w") as f:
    f.write(patched)

print(f"✓ Patched {count} occurrence(s) in {path}")
print(f"  {old}")
print(f"  → {new}")
