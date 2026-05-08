#!/usr/bin/env bash
set -euo pipefail

BASE="/workspaces/tsm-shell"
BUILD="$BASE/.fly-build-clean"
CORE="https://tsm-core.fly.dev"

mkdir -p "$BUILD"

build_app () {
  local src_file="$1"
  local app_name="$2"

  if [ ! -f "$BASE/$src_file" ]; then
    echo "Missing source file: $BASE/$src_file"
    return 1
  fi

  local dir="$BUILD/$app_name"
  rm -rf "$dir"
  mkdir -p "$dir"

  cp "$BASE/$src_file" "$dir/index.html"

  sed -i 's|https://ai.tsmatter.com/ask|'"$CORE"'/ask|g' "$dir/index.html"
  sed -i 's|https://ai.tsmatter.com/strategize|'"$CORE"'/strategize|g' "$dir/index.html"
  sed -i 's|https://ai.tsmatter.com/api/node/|'"$CORE"'/api/node/|g' "$dir/index.html"
  sed -i 's|https://strategist.tsmatter.com/ask|'"$CORE"'/ask|g' "$dir/index.html"
  sed -i 's|https://strategist.tsmatter.com/strategize|'"$CORE"'/strategize|g' "$dir/index.html"
  sed -i 's|ai.tsmatter.com|tsm-core.fly.dev|g' "$dir/index.html"
  sed -i 's|localhost:3200|tsm-core.fly.dev|g' "$dir/index.html"

  cat > "$dir/Dockerfile" <<'DOCKER'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
DOCKER

  cat > "$dir/fly.toml" <<TOML
app = "$app_name"
primary_region = "iad"

[http_service]
  internal_port = 80
  force_https = true
  auto_start_machines = true
  auto_stop_machines = "stop"
  min_machines_running = 0
TOML

  echo "Built $app_name from $src_file"
}

deploy_app () {
  local app_name="$1"
  local dir="$BUILD/$app_name"

  [ -d "$dir" ] || { echo "Missing build dir: $dir"; return 1; }

  echo
  echo "=== Deploying $app_name ==="
  fly apps create "$app_name" >/dev/null 2>&1 || true
  fly ips allocate-v4 --shared -a "$app_name" >/dev/null 2>&1 || true
  fly ips allocate-v6 -a "$app_name" >/dev/null 2>&1 || true

  (
    cd "$dir"
    fly deploy -a "$app_name" --ha=false
  )
}

# source file -> fly app name
build_app "legal-analyst-pro.html" "legal-analyst-pro"
build_app "agents-ins.html" "agents-ins"
build_app "dme.html" "tsm-dme"
build_app "bpo-legal.tsmatter.html" "bpo-legal"
build_app "auditops-pro.html" "auditops-pro"

deploy_app "legal-analyst-pro"
deploy_app "agents-ins"
deploy_app "tsm-dme"
deploy_app "bpo-legal"
deploy_app "auditops-pro"

echo
echo "Done."
echo "legal-analyst-pro -> https://legal-analyst-pro.fly.dev"
echo "agents-ins         -> https://agents-ins.fly.dev"
echo "tsm-dme            -> https://tsm-dme.fly.dev"
echo "bpo-legal          -> https://bpo-legal.fly.dev"
echo "auditops-pro       -> https://auditops-pro.fly.dev"
