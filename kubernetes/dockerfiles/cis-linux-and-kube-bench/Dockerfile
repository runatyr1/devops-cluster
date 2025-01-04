FROM debian:bookworm-slim

# Install base dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create reports directory
RUN mkdir -p /reports

# Create directory for linux-bench config
RUN mkdir -p ./cfg/2.0.0

# Download linux-bench definitions.yaml
RUN wget -O ./cfg/2.0.0/definitions.yaml https://raw.githubusercontent.com/aquasecurity/linux-bench/main/cfg/2.0.0/definitions.yaml

# Download and install the benchmark tools
RUN wget https://github.com/aquasecurity/kube-bench/releases/download/v0.9.4/kube-bench_0.9.4_linux_amd64.deb && \
    wget https://github.com/aquasecurity/linux-bench/releases/download/v0.5.0/linux-bench_0.5.0_linux_amd64.deb && \
    apt install -y ./kube-bench_0.9.4_linux_amd64.deb ./linux-bench_0.5.0_linux_amd64.deb && \
    rm *.deb

# Copy and set entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]