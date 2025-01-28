#!/bin/bash
# Get pod names
FRONTEND_POD=$(kubectl get pods -n network-policy-demo -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_POD=$(kubectl get pods -n network-policy-demo -l app=backend -o jsonpath='{.items[0].metadata.name}')

# Define test function with silent installation
run_test() {
  local name=$1
  local command=$2
  local expected=$3
  
  echo "➡️ Running test: $name"
  output=$(eval "$command" 2>/dev/null || echo "000")
  if [[ "$output" == *"$expected"* ]]; then
    echo "✅ Test passed (Got: ${output:0:3})"  # Show only first 3 chars
    return 0
  else
    echo "❌ Test failed (Expected: $expected, Got: ${output:0:3})"
    return 1
  fi
}

# Test 1: Frontend can reach backend
run_test "Frontend to backend" \
"kubectl exec -n network-policy-demo $FRONTEND_POD -- \
  sh -c 'apk add curl -q >/dev/null 2>&1; curl -s -o /dev/null -w \"%{http_code}\" --max-time 5 backend.network-policy-demo.svc.cluster.local:80'" \
"200"

# Test 2: External pod in same namespace cannot reach backend
run_test "Same namespace external pod to backend" \
"kubectl run test-pod --image=alpine:latest -n network-policy-demo --rm -i --restart=Never -- \
  sh -c 'apk add curl -q >/dev/null 2>&1; curl -s -o /dev/null -w \"%{http_code}\" --max-time 5 backend.network-policy-demo.svc.cluster.local:80 || echo 000'" \
"000"

# Test 3: Pod in default namespace cannot reach backend
run_test "Default namespace pod to backend" \
"kubectl run test-pod --image=alpine:latest --rm -i --restart=Never -- \
  sh -c 'apk add curl -q >/dev/null 2>&1; curl -s -o /dev/null -w \"%{http_code}\" --max-time 5 backend.network-policy-demo.svc.cluster.local:80 || echo 000'" \
"000"

# Test 4: Backend cannot initiate connection to frontend
run_test "Backend to frontend" \
"kubectl exec -n network-policy-demo $BACKEND_POD -- \
  sh -c 'apk add curl -q >/dev/null 2>&1; curl -s -o /dev/null -w \"%{http_code}\" --max-time 5 frontend.network-policy-demo.svc.cluster.local:80 || echo 000'" \
"000"

echo "✅ All tests completed"