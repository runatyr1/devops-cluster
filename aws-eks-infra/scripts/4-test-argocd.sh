#!/bin/bash
set -e

# Colors and setup
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_FAILED=0
CLUSTER_NAME="staging-eks"
PRIMARY_REGION="us-east-1"
SECONDARY_REGION="us-west-2"

# Helper functions
report_test() {
    local test_name=$1
    local result=$2
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓ $test_name${NC}"
    else
        echo -e "${RED}❌ $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Change to working directory
cd ../../../infrastructure/aws-eks/terraform/environments/staging

# Test ArgoCD in both clusters
for REGION in "$PRIMARY_REGION" "$SECONDARY_REGION"; do
    print_section "Testing ArgoCD in $REGION cluster"
    
    KUBECTL="kubectl --kubeconfig=k-aws-${REGION}.kubeconfig"

    # Test ArgoCD namespace
    $KUBECTL get namespace argocd &>/dev/null
    report_test "ArgoCD namespace exists in $REGION" $?

    # Test ArgoCD pods
    EXPECTED_PODS=5  # api, application-controller, redis, repo-server, server
    RUNNING_PODS=$($KUBECTL get pods -n argocd --field-selector=status.phase=Running --no-headers | wc -l)
    [ "$RUNNING_PODS" -eq $EXPECTED_PODS ]
    report_test "Expected number of ArgoCD pods running in $REGION" $?

    # Test ArgoCD services
    EXPECTED_SERVICES=4  # api, redis, repo-server, server
    SERVICE_COUNT=$($KUBECTL get svc -n argocd --no-headers | wc -l)
    [ "$SERVICE_COUNT" -eq $EXPECTED_SERVICES ]
    report_test "Expected number of ArgoCD services present in $REGION" $?

    # Test ArgoCD server endpoint
    SERVER_URL=$($KUBECTL get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ ! -z "$SERVER_URL" ]; then
        report_test "ArgoCD server endpoint available in $REGION" 0
    else
        report_test "ArgoCD server endpoint available in $REGION" 1
    fi

    # Test ArgoCD app synchronization
    APP_COUNT=$($KUBECTL get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$APP_COUNT" -gt 0 ]; then
        HEALTHY_APPS=$($KUBECTL get applications -n argocd -o jsonpath='{.items[?(@.status.health.status=="Healthy")].metadata.name}' 2>/dev/null | wc -w || echo "0")
        [ "$HEALTHY_APPS" -eq "$APP_COUNT" ]
        report_test "All ArgoCD applications are healthy in $REGION" $?
    else
        echo -e "${YELLOW}No ArgoCD applications found in $REGION${NC}"
    fi

    # Display ArgoCD resources
    echo -e "\n${YELLOW}ArgoCD Pods in $REGION:${NC}"
    $KUBECTL get pods -n argocd
    echo -e "\n${YELLOW}ArgoCD Services in $REGION:${NC}"
    $KUBECTL get svc -n argocd
done

# Export test results
LOG_FILE="../../../../aws-eks/scripts/log-4-argocd-$(date +%Y%m%d-%H%M%S).log"
{
    echo "ArgoCD Test Results - $(date)"
    echo "----------------------------------------"
    for REGION in "$PRIMARY_REGION" "$SECONDARY_REGION"; do
        echo "Region: $REGION"
        KUBECTL="kubectl --kubeconfig=k-aws-${REGION}.kubeconfig"
        echo "ArgoCD Pod Details:"
        $KUBECTL get pods -n argocd -o wide
        echo "ArgoCD Service Details:"
        $KUBECTL get svc -n argocd -o wide
        echo "ArgoCD Applications:"
        $KUBECTL get applications -n argocd -o wide 2>/dev/null || echo "No applications found"
        echo "----------------------------------------"
    done
} > "$LOG_FILE"

echo -e "\n${BLUE}Detailed test results have been exported to: $LOG_FILE${NC}"

cd -

exit $TESTS_FAILED