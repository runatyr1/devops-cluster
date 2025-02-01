# Use single stage with Node.js + Nginx
FROM node:18-alpine

# Install nginx
RUN apk add --no-cache nginx

WORKDIR /app

# Create project structure
RUN mkdir -p docs-site && \
    npm create astro@latest ./docs-site -- --yes --template=minimal && \
    cd docs-site && \
    npm install @astrojs/mdx && \
    mkdir -p src/pages/docs

# Copy config and entrypoint
COPY astro.config.mjs ./docs-site/
COPY entrypoint.sh .

# Setup nginx
COPY nginx.conf /etc/nginx/nginx.conf

WORKDIR /app/docs-site
EXPOSE 80
CMD ["sh", "../entrypoint.sh"]