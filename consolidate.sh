#!/bin/bash
set -e

echo "=============================="
echo "  TSM-SHELL CONSOLIDATION"
echo "=============================="

SHELL_APP="tsm-shell"
HTML_DIR="./html"

# ── 1. BUILD FOLDER STRUCTURE FROM EXISTING HTML FILES ──────────────────────
echo ""
echo "📁 Organizing HTML files into folders..."
mkdir -p "$HTML_DIR"

for html_file in *.html; do
  [ -f "$html_file" ] || continue
  folder_name="${html_file%.html}"
  mkdir -p "$HTML_DIR/$folder_name"
  cp "$html_file" "$HTML_DIR/$folder_name/index.html"
  echo "  ✓ $html_file → html/$folder_name/index.html"
done

# ── 2. GENERATE MASTER nginx.conf FROM *.nginx FILES ────────────────────────
echo ""
echo "⚙️  Generating nginx.conf from domain config files..."

cat > nginx.conf << 'NGINX_HEADER'
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout  65;

    # Default fallback
    server {
        listen 80 default_server;
        root /usr/share/nginx/html/default;
        index index.html;
    }

NGINX_HEADER

# Pull in each *.nginx domain config
for nginx_file in *.nginx; do
  [ -f "$nginx_file" ] || continue
  domain="${nginx_file%.nginx}"
  echo "  ✓ Including $nginx_file ($domain)"
  cat "$nginx_file" >> nginx.conf
  echo "" >> nginx.conf
done

# Also auto-generate blocks for any HTML files that don't have a .nginx file
for html_file in *.html; do
  [ -f "$html_file" ] || continue
  folder_name="${html_file%.html}"
  nginx_file="$folder_name.nginx"
  [ -f "$nginx_file" ] && continue  # already handled above
  echo "  ✓ Auto-generating server block for $folder_name"
  cat >> nginx.conf << EOF
    server {
        listen 80;
        server_name $folder_name.*;
        root /usr/share/nginx/html/$folder_name;
        index index.html;
        location / {
            try_files \$uri \$uri/ /index.html;
        }
    }

EOF
done

echo "}" >> nginx.conf
echo "  ✅ nginx.conf written"

# ── 3. WRITE DOCKERFILE ──────────────────────────────────────────────────────
echo ""
echo "🐳 Writing Dockerfile..."
cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY html/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
echo "  ✅ Dockerfile written"

# ── 4. VALIDATE NGINX CONFIG ─────────────────────────────────────────────────
echo ""
echo "🔍 Validating nginx config..."
docker run --rm -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf nginx:alpine nginx -t 2>&1
echo "  ✅ nginx config valid"

# ── 5. DESTROY ALL FLY APPS EXCEPT tsm-shell ────────────────────────────────
echo ""
echo "🗑️  Destroying all Fly apps except $SHELL_APP..."

APPS=$(fly apps list --json | jq -r '.[].Name' | grep -v "^${SHELL_APP}$" | grep -v "^${SHELL_APP}-db$")

for app in $APPS; do
  echo "  Destroying $app..."
  fly apps destroy "$app" --yes 2>&1 | tail -1
done
echo "  ✅ All other apps destroyed"

# ── 6. ADD CERTS FOR ALL DOMAINS FOUND IN *.nginx FILES ─────────────────────
echo ""
echo "🔒 Adding SSL certs to $SHELL_APP..."

for nginx_file in *.nginx; do
  [ -f "$nginx_file" ] || continue
  domain="${nginx_file%.nginx}"
  echo "  Adding cert for $domain..."
  fly certs add "$domain" --app "$SHELL_APP" 2>&1 | tail -1 || true
done
echo "  ✅ Certs added"

# ── 7. DEPLOY ────────────────────────────────────────────────────────────────
echo ""
echo "🚀 Deploying $SHELL_APP..."
fly deploy --app "$SHELL_APP" --remote-only

echo ""
echo "=============================="
echo "  ✅ DONE — 1 machine, all apps"
echo "=============================="
