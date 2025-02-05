#!/bin/bash

# Initialize variables for test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directory containing test scripts
TEST_DIR="$(dirname "$0")"

# Function to run a test script and collect results
run_test() {
    local test_script=$1
    echo -e "\n${BLUE}Running test: ${test_script}${NC}"
    
    if $TEST_DIR/$test_script; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Run all test scripts in order
for test_script in $(ls ${TEST_DIR}/[0-9]*-test-*.sh | sort -r); do
    if [ "$test_script" != "$0" ]; then  # Don't run self
        run_test $(basename $test_script)
    fi
done

# Print summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "Total Tests: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"

# Exit with status based on test results
[ $FAILED_TESTS -eq 0 ]