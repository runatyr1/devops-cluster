#!/bin/bash
set -e

# Create directories
mkdir -p /reports
mkdir -p ./cfg/2.0.0
mkdir -p ./cfg-kube/cis-1.24

# Download linux-bench definitions.yaml
wget -O ./cfg/2.0.0/definitions.yaml https://raw.githubusercontent.com/aquasecurity/linux-bench/main/cfg/2.0.0/definitions.yaml

# Download kube-bench configs
wget -O ./cfg-kube/config.yaml https://raw.githubusercontent.com/aquasecurity/kube-bench/main/cfg/config.yaml
for file in config.yaml controlplane.yaml etcd.yaml master.yaml node.yaml policies.yaml; do
    wget -O ./cfg-kube/cis-1.24/${file} https://raw.githubusercontent.com/aquasecurity/kube-bench/main/cfg/cis-1.24/${file}
done

# Download benchmark tools
wget https://github.com/aquasecurity/kube-bench/releases/download/v0.9.4/kube-bench_0.9.4_linux_amd64.deb
wget https://github.com/aquasecurity/linux-bench/releases/download/v0.5.0/linux-bench_0.5.0_linux_amd64.deb

# Install benchmark tools
apt install -y ./kube-bench_0.9.4_linux_amd64.deb ./linux-bench_0.5.0_linux_amd64.deb

# Clean up
rm *.deb