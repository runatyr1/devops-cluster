#!/bin/sh
set -e

# 1. Copy latest docs from PVC
echo "Syncing docs content..."
mkdir -p /app/docs-site/src/pages/docs

# Copy files preserving directory structure
cd /docs-content
find . -type f \( -name "*.md" -o -name "*.mdx" -o -name "_category_.json" \) -exec sh -c '
    mkdir -p "/app/docs-site/src/pages/docs/$(dirname "{}")"
    cp "{}" "/app/docs-site/src/pages/docs/{}"
' \;

# Copy images if they exist
find . -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.svg" \) -exec sh -c '
    mkdir -p "/app/docs-site/public/docs/$(dirname "{}")"
    cp "{}" "/app/docs-site/public/docs/{}"
' \;

# 2. Build site with latest content
echo "Building documentation site..."
cd /app/docs-site
npm run build

# 3. Clear old files and copy new build
echo "Updating nginx content..."
rm -rf /usr/share/nginx/html/*
cp -R dist/* /usr/share/nginx/html/

# Healt check improvement
echo "docs-version: $(date +%s)" > /usr/share/nginx/html/health

# 4. Start server
echo "Starting nginx..."
exec nginx -g 'daemon off;'