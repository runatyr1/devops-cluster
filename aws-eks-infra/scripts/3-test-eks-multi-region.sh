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

# Test both regions' clusters
for REGION in "$PRIMARY_REGION" "$SECONDARY_REGION"; do
    print_section "Testing EKS Cluster in $REGION"
    
    # Update kubeconfig for current region
    aws eks update-kubeconfig \
        --name $CLUSTER_NAME \
        --region $REGION \
        --kubeconfig k-aws-${REGION}.kubeconfig \
        --alias staging-eks-${REGION}
    
    KUBECTL="kubectl --kubeconfig=k-aws-${REGION}.kubeconfig"

    # Test cluster status
    CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
    [ "$CLUSTER_STATUS" = "ACTIVE" ]
    report_test "EKS cluster in $REGION is active" $?

    # Test node count
    EXPECTED_NODES=2
    if [ "$REGION" = "$SECONDARY_REGION" ]; then
        EXPECTED_NODES=1
    fi
    
    NODE_COUNT=$($KUBECTL get nodes --no-headers | wc -l)
    [ "$NODE_COUNT" -eq $EXPECTED_NODES ]
    report_test "Expected number of nodes ($EXPECTED_NODES) in $REGION" $?

    # Test node distribution
    if [ "$REGION" = "$PRIMARY_REGION" ]; then
        AZ_COUNT=$($KUBECTL get nodes -o jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}' | tr ' ' '\n' | sort -u | wc -l)
        [ "$AZ_COUNT" -eq 2 ]
        report_test "Nodes distributed across 2 AZs in primary region" $?
    else
        AZ_COUNT=$($KUBECTL get nodes -o jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}' | tr ' ' '\n' | sort -u | wc -l)
        [ "$AZ_COUNT" -eq 1 ]
        report_test "Node in single AZ in secondary region" $?
    fi

    # Test VPC peering
    if [ "$REGION" = "$PRIMARY_REGION" ]; then
        VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)
        PEERING_CONNECTION=$(aws ec2 describe-vpc-peering-connections --region $REGION --filters "Name=requester-vpc-info.vpc-id,Values=$VPC_ID" --query 'VpcPeeringConnections[0].Status.Code' --output text)
        [ "$PEERING_CONNECTION" = "active" ]
        report_test "VPC peering connection is active" $?
    fi

    # Test OIDC provider
    OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.identity.oidc.issuer' --output text)
    OIDC_PROVIDER_EXISTS=$(aws iam list-open-id-connect-providers --region $REGION | grep $(echo $OIDC_URL | cut -d '/' -f 5) || true)
    [ ! -z "$OIDC_PROVIDER_EXISTS" ]
    report_test "OIDC provider configured in $REGION" $?

    echo -e "\n${YELLOW}Nodes in $REGION:${NC}"
    $KUBECTL get nodes -o wide
done

# Export test results
LOG_FILE="../../../../aws-eks/scripts/log-3-eks-multi-region-$(date +%Y%m%d-%H%M%S).log"
{
    echo "EKS Multi-Region Test Results - $(date)"
    echo "----------------------------------------"
    for REGION in "$PRIMARY_REGION" "$SECONDARY_REGION"; do
        echo "Region: $REGION"
        echo "Cluster Name: $CLUSTER_NAME"
        KUBECTL="kubectl --kubeconfig=k-aws-${REGION}.kubeconfig"
        echo "Node Details:"
        $KUBECTL get nodes -o wide
        echo "Cluster Details:"
        aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --output json
        echo "----------------------------------------"
    done
} > "$LOG_FILE"

echo -e "\n${BLUE}Detailed test results have been exported to: $LOG_FILE${NC}"

cd -

exit $TESTS_FAILED