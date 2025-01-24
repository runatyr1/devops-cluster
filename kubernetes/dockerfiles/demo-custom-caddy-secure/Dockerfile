FROM caddy:2-alpine

# Create non-root user and setup directories
RUN addgroup -S nonroot && \
    adduser -u 65532 -S -D -H -G nonroot nonroot && \
    mkdir -p /data /config && \
    chown -R nonroot:nonroot /data /config && \
    chmod -R 755 /data /config

# Security hardening
RUN apk update && \
    apk add --no-cache libcap && \
    apk upgrade && \
    rm -rf /var/cache/apk/* && \
    setcap cap_net_bind_service=+ep /usr/bin/caddy

USER nonroot:nonroot

VOLUME ["/data", "/config"]
EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80 || exit 1

CMD ["caddy", "run", "--config", "/config/Caddyfile", "--adapter", "caddyfile"]