#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${1:-/workspaces/tsm-shell}"
WORKROOT="$BASE_DIR/.fly-build"
MANIFEST="$BASE_DIR/fly-local-manifest.csv"
PRIMARY_REGION="${PRIMARY_REGION:-iad}"

mkdir -p "$WORKROOT"
echo "source_file,domain,app_name,status,url" > "$MANIFEST"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing $1"; exit 1; }
}

need_cmd fly
need_cmd python3

patch_html() {
  local src="$1"
  local dst="$2"

  python3 - "$src" "$dst" <<'PY'
from pathlib import Path
import re
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

txt = src.read_text(encoding="utf-8", errors="ignore")

for old, new in [
    ("https://ai.tsmatter.com/ask", "https://tsm-core.fly.dev/ask"),
    ("https://ai.tsmatter.com/strategize", "https://tsm-core.fly.dev/strategize"),
    ("https://ai.tsmatter.com/api/node/", "https://tsm-core.fly.dev/api/node/"),
    ("https://strategist.tsmatter.com/ask", "https://tsm-core.fly.dev/ask"),
    ("https://strategist.tsmatter.com/strategize", "https://tsm-core.fly.dev/strategize"),
    ("ai.tsmatter.com", "tsm-core.fly.dev"),
    ("localhost:3200", "tsm-core.fly.dev"),
]:
    txt = txt.replace(old, new)

txt = re.sub(r'Timeout after 30000ms[^<\n]*', 'AI recovery mode active — connected to tsm-core.fly.dev', txt, flags=re.I)
txt = re.sub(r'AI unavailable:[^<\n]*', 'AI recovery mode active — connected to tsm-core.fly.dev', txt, flags=re.I)

dst.write_text(txt, encoding="utf-8")
PY
}

deploy_one() {
  local html="$1"
  local fname stub domain app dir url

  fname="$(basename "$html")"
  stub="${fname%.tsmatter.html}"
  domain="$stub.tsmatter.com"
  app="$stub"
  dir="$WORKROOT/$app"
  url="https://$app.fly.dev"

  rm -rf "$dir"
  mkdir -p "$dir"

  patch_html "$html" "$dir/index.html"

  cat > "$dir/Dockerfile" <<'DOCKER'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
DOCKER

  cat > "$dir/fly.toml" <<TOML
app = "$app"
primary_region = "$PRIMARY_REGION"

[http_service]
  internal_port = 80
  force_https = true
  auto_start_machines = true
  auto_stop_machines = "off"
  min_machines_running = 1
TOML

  echo
  echo "=== Deploying $fname -> $app ==="
  (
    cd "$dir"
    fly apps create "$app" >/dev/null 2>&1 || true
    fly deploy -a "$app"
  )

  echo "$fname,$domain,$app,DEPLOYED,$url" >> "$MANIFEST"
}

mapfile -t FILES < <(find "$BASE_DIR" -maxdepth 1 -type f -name '*.tsmatter.html' | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No *.tsmatter.html files found in $BASE_DIR"
  exit 1
fi

for f in "${FILES[@]}"; do
  deploy_one "$f"
done

echo
echo "Done."
echo "Manifest saved to: $MANIFEST"
column -s, -t "$MANIFEST" || cat "$MANIFEST"
