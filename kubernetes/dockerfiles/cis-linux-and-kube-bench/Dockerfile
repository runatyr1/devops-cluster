FROM debian:bookworm-slim

# Install base dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

COPY bootstrap.sh /tmp/bootstrap.sh

RUN chmod +x /tmp/bootstrap.sh && /tmp/bootstrap.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]