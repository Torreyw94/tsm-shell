#!/usr/bin/env bash
set -e

BASE="/workspaces/tsm-shell"
BUILD="$BASE/.fly-build"

mkdir -p "$BUILD"

echo "== CLEAN DEPLOY START =="

for f in "$BASE"/*.tsmatter.html; do
  [ -f "$f" ] || continue

  name=$(basename "$f" .tsmatter.html)
  app="$name"
  dir="$BUILD/$app"

  echo
  echo "Deploying: $f -> $app"

  rm -rf "$dir"
  mkdir -p "$dir"

  # Copy as index.html
  cp "$f" "$dir/index.html"

  # Fix AI endpoints (CRITICAL)
  sed -i 's|ai.tsmatter.com|tsm-core.fly.dev|g' "$dir/index.html"
  sed -i 's|localhost:3200|tsm-core.fly.dev|g' "$dir/index.html"

  # Dockerfile
  cat > "$dir/Dockerfile" <<DOCKER
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
DOCKER

  # fly.toml (lighter + stable)
  cat > "$dir/fly.toml" <<TOML
app = "$app"
primary_region = "iad"

[http_service]
  internal_port = 80
  force_https = true
  auto_start_machines = true
  auto_stop_machines = "stop"
  min_machines_running = 0
TOML

  cd "$dir"

  # Create app if missing
  fly apps create "$app" 2>/dev/null || true

  # Fix IP issues BEFORE deploy
  fly ips allocate-v4 --shared -a "$app" 2>/dev/null || true
  fly ips allocate-v6 -a "$app" 2>/dev/null || true

  # Deploy
  fly deploy -a "$app"

done

echo
echo "== CLEAN DEPLOY COMPLETE =="
