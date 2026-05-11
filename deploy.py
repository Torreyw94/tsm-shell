#!/usr/bin/env python3
"""
TSM Deploy — One Shot
Double-click or run: python deploy.py
Drag your file in, hit Enter, done.
"""
import base64, json, os, sys, urllib.request, urllib.error

OWNER  = "Torreyw94"
REPO   = "tsm-shell"
BRANCH = "main"

PATHS = {
    "finops-main-strategist": "html/finops-suite/finops-main-strategist/index.html",
    "index":                  "html/finops-suite/index.html",
    "financial-command":      "html/finops-suite/financial-command/index.html",
    "financial":              "html/finops-suite/financial/index.html",
    "tax":                    "html/finops-suite/tax.html",
    "compliance":             "html/finops-suite/compliance.html",
    "zero-trust":             "html/finops-suite/zero-trust.html",
    "finops-operations":      "html/finops-suite/finops-operations.html",
    "finops-showcase-v2":     "html/finops-suite/finops-showcase-v2.html",
}

def ask(prompt, default=""):
    val = input(f"{prompt} [{default}]: ").strip() if default else input(f"{prompt}: ").strip()
    return val or default

def put(url, token, data):
    req = urllib.request.Request(url,
        data=json.dumps(data).encode(),
        headers={"Authorization": f"Bearer {token}",
                 "Accept": "application/vnd.github+json",
                 "Content-Type": "application/json"},
        method="PUT")
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        print("GitHub error:", e.read().decode()); sys.exit(1)

def sha(path, token):
    req = urllib.request.Request(
        f"https://api.github.com/repos/{OWNER}/{REPO}/contents/{path}?ref={BRANCH}",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read()).get("sha")
    except urllib.error.HTTPError:
        return None

print("\n★  TSM ONE-SHOT DEPLOY  ★\n")

# Token
token = os.environ.get("GITHUB_TOKEN","").strip() or ask("GitHub token (ghp_...)")

# File — strip quotes from drag-and-drop
raw = ask("File path (drag & drop OK)")
local = raw.strip().strip("'\"")
if not os.path.exists(local):
    print("File not found:", local); sys.exit(1)

# Destination
name = os.path.splitext(os.path.basename(local))[0]
default_key = next((k for k in PATHS if name.startswith(k)), None)
print("\nKnown targets:")
for i,(k,v) in enumerate(PATHS.items()): print(f"  {i+1}. {k}  →  {v}")
print(f"  0. Custom path")
pick = ask("\nPick number or type custom path", str(list(PATHS.keys()).index(default_key)+1) if default_key else "1")

if pick.isdigit() and 1 <= int(pick) <= len(PATHS):
    repo_path = list(PATHS.values())[int(pick)-1]
elif pick == "0":
    repo_path = ask("Full repo path (html/finops-suite/...)")
else:
    repo_path = pick  # typed a path directly

print(f"\n→ {local}")
print(f"→ {OWNER}/{REPO}/{repo_path}\n")

confirm = ask("Deploy? (y/n)", "y")
if confirm.lower() != "y":
    print("Cancelled."); sys.exit(0)

with open(local,"rb") as f:
    content = base64.b64encode(f.read()).decode()

existing_sha = sha(repo_path, token)
payload = {"message": f"deploy: {repo_path.split('/')[-1]}", "content": content, "branch": BRANCH}
if existing_sha:
    payload["sha"] = existing_sha

result = put(f"https://api.github.com/repos/{OWNER}/{REPO}/contents/{repo_path}", token, payload)
print("✓ Done!", result["commit"]["sha"][:12])
print("  ", result["commit"]["html_url"])
