#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Starting idempotency tests for Kubernetes bootstrap playbook..."

# Test 1: Run playbook twice
echo "Test 1: Running playbook twice to verify idempotency..."
ansible-playbook bootstrap.yml
CHANGED_COUNT_1=$(ansible-playbook bootstrap.yml | grep -c 'changed=' || true)

if [ "$CHANGED_COUNT_1" -eq 0 ]; then
    echo -e "${GREEN}✓ Idempotency test passed: No changes on second run${NC}"
else
    echo -e "${RED}✗ Idempotency test failed: $CHANGED_COUNT_1 changes on second run${NC}"
fi

# Test 2: Verify critical services
echo "Test 2: Verifying critical services..."
services=("containerd" "kubelet")
for service in "${services[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Service $service is running${NC}"
    else
        echo -e "${RED}✗ Service $service is not running${NC}"
        exit 1
    fi
done

# Test 3: Verify Kubernetes cluster health
echo "Test 3: Verifying Kubernetes cluster health..."
if kubectl get nodes | grep -q "Ready"; then
    echo -e "${GREEN}✓ Kubernetes node is Ready${NC}"
else
    echo -e "${RED}✗ Kubernetes node is not Ready${NC}"
    exit 1
fi

# Test 4: Verify Cilium installation
echo "Test 4: Verifying Cilium installation..."
if kubectl -n kube-system get pods | grep -q "cilium" && \
   kubectl -n kube-system get pods | grep "cilium" | grep -q "Running"; then
    echo -e "${GREEN}✓ Cilium pods are running${NC}"
else
    echo -e "${RED}✗ Cilium pods are not running properly${NC}"
    exit 1
fi

# Test 5: Verify system configurations
echo "Test 5: Verifying system configurations..."
configs=(
    "net.bridge.bridge-nf-call-iptables=1"
    "net.bridge.bridge-nf-call-ip6tables=1"
    "net.ipv4.ip_forward=1"
)

for config in "${configs[@]}"; do
    key="${config%=*}"
    value="${config#*=}"
    current_value=$(sysctl -n "$key")
    if [ "$current_value" = "$value" ]; then
        echo -e "${GREEN}✓ System config $key is correctly set${NC}"
    else
        echo -e "${RED}✗ System config $key is not correctly set${NC}"
        exit 1
    fi
done

echo -e "\n${GREEN}All tests completed successfully!${NC}"