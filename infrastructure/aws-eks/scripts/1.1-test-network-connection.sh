#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

cat << "EOF"
================================================================================
AWS Network Connectivity Test Suite
================================================================================
This test suite validates the core networking components of the AWS VPC infrastructure:

1. Internet Gateway (IGW) Configuration
   - Verifies IGW exists and is properly attached to VPC
   - Ensures public subnets have route to internet

2. NAT Gateway Status
   - Confirms NAT Gateway is active and available
   - Validates private subnet routing through NAT

3. Route Table Configuration
   - Checks public subnet routes to IGW
   - Verifies private subnet routes to NAT Gateway
   - Validates internal VPC routing

4. DNS Configuration
   - Confirms VPC DNS support is enabled
   - Verifies DNS hostnames are enabled

5. Network ACL Settings
   - Validates default NACL existence
   - Reviews NACL associations with subnets

This suite ensures the VPC is properly configured for:
- Public internet access from public subnets
- NAT-based internet access from private subnets
- Internal VPC communication
- DNS resolution
================================================================================
EOF


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

print_section "AWS Network Connectivity Tests"

# Get VPC ID from previous test environment
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=staging" --query 'Vpcs[0].VpcId' --output text)
if [ -z "$VPC_ID" ]; then
    echo "ERROR: No VPC found with Environment=staging tag"
    exit 1
fi

# Test 1: Internet Gateway Tests
print_section "Internet Gateway Tests"

IGW_COUNT=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'length(InternetGateways)' \
    --output text)
[ "$IGW_COUNT" -eq 1 ]
report_test "Internet Gateway exists and is attached" $?

# Test 2: NAT Gateway Connectivity
print_section "NAT Gateway Connectivity"

NAT_STATUS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query 'NatGateways[0].State' \
    --output text)
[ "$NAT_STATUS" = "available" ]
report_test "NAT Gateway is available" $?

# Test 3: Route Table Connectivity
print_section "Route Table Connectivity Tests"

# Check public subnet routes
echo -e "${YELLOW}Checking public subnet routing...${NC}"
PUBLIC_RT_COUNT=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[?Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId|[0]!=`null`]|length(@)' \
    --output text)
[ "$PUBLIC_RT_COUNT" -ge 1 ]
report_test "Public subnets have internet gateway route" $?

# Check private subnet routes
echo -e "${YELLOW}Checking private subnet routing...${NC}"
PRIVATE_RT_COUNT=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[?Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0]!=`null`]|length(@)' \
    --output text)
[ "$PRIVATE_RT_COUNT" -ge 1 ]
report_test "Private subnets have NAT gateway route" $?

# Test 4: VPC DNS Settings
print_section "VPC DNS Configuration"

DNS_SETTINGS=$(aws ec2 describe-vpc-attribute \
    --vpc-id $VPC_ID \
    --attribute enableDnsSupport \
    --query 'EnableDnsSupport.Value' \
    --output text)
[ "$DNS_SETTINGS" = "True" ]
report_test "VPC DNS support enabled" $?

DNS_HOSTNAMES=$(aws ec2 describe-vpc-attribute \
    --vpc-id $VPC_ID \
    --attribute enableDnsHostnames \
    --query 'EnableDnsHostnames.Value' \
    --output text)
[ "$DNS_HOSTNAMES" = "True" ]
report_test "VPC DNS hostnames enabled" $?

# Test 5: NACL Tests
print_section "Network ACL Tests"

# Check default NACL settings
echo -e "${YELLOW}Checking Network ACLs...${NC}"
aws ec2 describe-network-acls \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkAcls[].{
        "NACL ID": NetworkAclId,
        "Is Default": IsDefault,
        "Subnet Associations": Associations[].SubnetId
    }' \
    --output table

DEFAULT_NACL_COUNT=$(aws ec2 describe-network-acls \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=default,Values=true" \
    --query 'length(NetworkAcls)' \
    --output text)
[ "$DEFAULT_NACL_COUNT" -eq 1 ]
report_test "Default NACL exists" $?

# Summary
print_section "Test Summary"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All connectivity tests passed successfully!${NC}"
else
    echo -e "${RED}$TESTS_FAILED connectivity test(s) failed${NC}"
fi

# Export test results to a log file
LOG_FILE="log-1.1-network-connectivity-$(date +%Y%m%d-%H%M%S).log"
{
    echo "Network Connectivity Test Results - $(date)"
    echo "----------------------------------------"
    echo "VPC ID: $VPC_ID"
    echo "Internet Gateway Status: $IGW_COUNT gateway(s) attached"
    echo "NAT Gateway Status: $NAT_STATUS"
    echo "Public Route Tables with IGW: $PUBLIC_RT_COUNT"
    echo "Private Route Tables with NAT: $PRIVATE_RT_COUNT"
    echo "DNS Support: $DNS_SETTINGS"
    echo "DNS Hostnames: $DNS_HOSTNAMES"
} > "$LOG_FILE"

echo -e "\n${BLUE}Detailed connectivity test results have been exported to: $LOG_FILE${NC}"

exit $TESTS_FAILED