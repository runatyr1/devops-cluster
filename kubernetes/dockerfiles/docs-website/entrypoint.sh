#!/bin/sh
set -e

# 1. Copy latest docs from PVC
echo "Syncing docs content..."
rm -rf /app/docs-site/src/pages/docs/*
cp -R /docs-content/* /app/docs-site/src/pages/docs/

# 2. Rebuild site with latest content
echo "Building documentation site..."
cd /app/docs-site
npm run build

# 3. Clear old files and copy new build
echo "Updating nginx content..."
rm -rf /usr/share/nginx/html/*
cp -R dist/* /usr/share/nginx/html/

# 4. Start server
echo "Starting nginx..."
exec nginx -g 'daemon off;'