#!/bin/bash
set -e

# Function to install aws-iam-authenticator if not present
install_authenticator() {
    if ! command -v aws-iam-authenticator &> /dev/null; then
        print_section "Installing aws-iam-authenticator"
        curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.6.11/aws-iam-authenticator_0.6.11_linux_amd64
        chmod +x ./aws-iam-authenticator
        sudo mv aws-iam-authenticator /usr/local/bin
        report_test "aws-iam-authenticator installation" $?
    else
        echo -e "${GREEN}aws-iam-authenticator is already installed${NC}"
    fi
}

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

install_authenticator

# Initialize test counter
TESTS_FAILED=0

# Function to report test result
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

# Function to print section header
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Change to correct directory
cd ../../../infrastructure/aws-eks/terraform/environments/staging

print_section "AWS Authentication Check"
# Check AWS session
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}ERROR: AWS session is not active. Please authenticate first.${NC}"
    exit 1
fi
report_test "AWS session is active" $?

print_section "Kubeconfig Setup"
# Update kubeconfig with explicit auth settings
# Update kubeconfig
aws eks update-kubeconfig \
    --name staging-eks \
    --region us-east-1 \
    --kubeconfig staging-eks.kubeconfig \
    --alias staging-eks

# Define kubectl command with config
KUBECTL="kubectl --kubeconfig=staging-eks.kubeconfig"

print_section "AWS EKS Control Plane Tests"

# Get cluster name from environment
CLUSTER_NAME="staging-eks"

# Test 1: Cluster Availability
print_section "Cluster Availability Test"

CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.status' --output text)
[ "$CLUSTER_STATUS" = "ACTIVE" ]
report_test "EKS cluster is active" $?

# Test 2: Cluster API Access
print_section "Cluster API Access Test"

$KUBECTL version
report_test "kubectl can connect to cluster" $?

# Test 3: Node Group Status
print_section "Node Group Test"

NODE_COUNT=$($KUBECTL get nodes --no-headers | wc -l)
[ "$NODE_COUNT" -eq 2 ]
report_test "Expected number of nodes (2) are present" $?

$KUBECTL get nodes
echo -e "${YELLOW}Current nodes in cluster:${NC}"

# Test 4: OIDC Provider Configuration
print_section "OIDC Provider Test"

OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.identity.oidc.issuer' --output text)
OIDC_PROVIDER_EXISTS=$(aws iam list-open-id-connect-providers | grep $(echo $OIDC_URL | cut -d '/' -f 5) || true)
[ ! -z "$OIDC_PROVIDER_EXISTS" ]
report_test "OIDC provider is configured" $?

# Test 5: IAM Role Test
print_section "IAM Roles Test"

# Create test service account and pod
cat << EOF | $KUBECTL apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-sa
  namespace: default
EOF

SA_EXISTS=$($KUBECTL get serviceaccount test-sa -n default -o name)
[ ! -z "$SA_EXISTS" ]
report_test "Service account creation successful" $?

# Test 6: Security Groups
print_section "Security Group Configuration"

CLUSTER_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
SG_RULES=$(aws ec2 describe-security-groups --group-ids $CLUSTER_SG --query 'SecurityGroups[0].IpPermissions' --output text)
[ ! -z "$SG_RULES" ]
report_test "Cluster security group is configured" $?

# Clean up test resources
$KUBECTL delete serviceaccount test-sa -n default

# Summary
print_section "Test Summary"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All EKS control plane tests passed successfully!${NC}"
else
    echo -e "${RED}$TESTS_FAILED test(s) failed${NC}"
fi



# Export test results
LOG_FILE="../../../../aws-eks/scripts/log-2-eks-control-plane-$(date +%Y%m%d-%H%M%S).log"
{
    echo "EKS Control Plane Test Results - $(date)"
    echo "----------------------------------------"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Cluster Status: $CLUSTER_STATUS"
    echo "Node Count: $NODE_COUNT"
    echo "OIDC Provider: $OIDC_URL"
    echo "----------------------------------------"
    echo "Node Details:"
    $KUBECTL get nodes -o wide
    echo "----------------------------------------"
    aws eks describe-cluster --name $CLUSTER_NAME --output json
} > "$LOG_FILE"

echo -e "\n${BLUE}Detailed test results have been exported to: $LOG_FILE${NC}"

cd -

exit $TESTS_FAILED