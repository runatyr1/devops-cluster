#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

print_section "AWS Network Infrastructure Test Results"

# Test 1: VPC Details
print_section "VPC Information"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=staging" --query 'Vpcs[0].VpcId' --output text)
report_test "VPC exists: $VPC_ID" $?

echo -e "${YELLOW}VPC Details:${NC}"
aws ec2 describe-vpcs --vpc-ids $VPC_ID \
    --query 'Vpcs[0].{
        "CIDR Block": CidrBlock,
        "VPC ID": VpcId,
        "State": State,
        "Tags": Tags[*].{Key: Key, Value: Value}
    }' \
    --output table

# Test 2: Availability Zones
print_section "Availability Zones"
echo -e "${YELLOW}AZs in use by our VPC subnets:${NC}"
aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].{
        "AZ": AvailabilityZone,
        "Subnet Type": Tags[?Key==`Name`].Value|[0],
        "CIDR": CidrBlock
    }' \
    --output table

# Count unique AZs using shell
AZ_COUNT=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].AvailabilityZone' \
    --output text | tr '\t' '\n' | sort -u | wc -l)
[ "$AZ_COUNT" -eq 2 ]
report_test "Correct number of AZs (expected 2): $AZ_COUNT" $?

# Show which AZs are in use
echo -e "${YELLOW}Summary of AZ distribution:${NC}"
aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].AvailabilityZone' \
    --output text | tr '\t' '\n' | sort -u | while read az; do
    SUBNET_COUNT=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=availability-zone,Values=$az" \
        --query 'length(Subnets)' \
        --output text)
    echo "- $az ($SUBNET_COUNT subnets)"
done

# Test 3: Subnet Information
print_section "Subnet Configuration"
SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'length(Subnets)' --output text)
[ "$SUBNET_COUNT" -eq 4 ]
report_test "Found correct number of subnets: $SUBNET_COUNT" $?

echo -e "${YELLOW}Subnet Details:${NC}"
aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,Tags[?Key==`Name`].Value|[0],MapPublicIpOnLaunch]' \
    --output table

# Test 4: NAT Gateway
print_section "NAT Gateway Configuration"
NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query 'length(NatGateways)' --output text)
[ "$NAT_COUNT" -ge 1 ]
report_test "NAT Gateway exists" $?

echo -e "${YELLOW}NAT Gateway Details:${NC}"
aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" \
    --query 'NatGateways[].[NatGatewayId,SubnetId,State,NatGatewayAddresses[0].PublicIp]' \
    --output table

# Test 5: Route Tables
print_section "Route Tables Configuration"
ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'length(RouteTables)' --output text)
[ "$ROUTE_TABLES" -ge 3 ]
report_test "Route tables configured correctly" $?

echo -e "${YELLOW}Route Table Details:${NC}"
aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'RouteTables[].[RouteTableId,Associations[0].SubnetId,Tags[?Key==`Name`].Value|[0]]' \
    --output table

echo -e "\n${YELLOW}Route Details for each Route Table:${NC}"
for rt in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[].RouteTableId' --output text); do
    echo -e "${YELLOW}Routes for $rt:${NC}"
    aws ec2 describe-route-tables \
        --route-table-ids $rt \
        --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId,State]' \
        --output table
done

# Test 6: VPC Tags
print_section "VPC Tagging"
VPC_TAGS=$(aws ec2 describe-vpcs --vpc-id $VPC_ID --query 'Vpcs[0].Tags[?Key==`Environment`].Value' --output text)
[ "$VPC_TAGS" == "staging" ]
report_test "VPC properly tagged" $?

echo -e "${YELLOW}All VPC Tags:${NC}"
aws ec2 describe-vpcs \
    --vpc-ids $VPC_ID \
    --query 'Vpcs[].Tags[]' \
    --output table



# Summary
print_section "Test Summary"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
else
    echo -e "${RED}$TESTS_FAILED test(s) failed${NC}"
fi

# Export infrastructure details to a log file
LOG_FILE="log-1-network-infrastructure-$(date +%Y%m%d-%H%M%S).log"
{
    echo "Network Infrastructure Details - $(date)"
    echo "----------------------------------------"
    aws ec2 describe-vpcs --vpc-ids $VPC_ID --output json
    echo "----------------------------------------"
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --output json
    echo "----------------------------------------"
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --output json
} > "$LOG_FILE"

echo -e "\n${BLUE}Detailed infrastructure information has been exported to: $LOG_FILE${NC}"

exit $TESTS_FAILED