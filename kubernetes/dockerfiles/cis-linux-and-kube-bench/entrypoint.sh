#!/bin/bash
set -e

TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
CIS_LINUX_REPORT="/reports/${TIMESTAMP}-CIS-Linux-report.log"
CIS_KUBE_REPORT="/reports/${TIMESTAMP}-CIS-kube-bench-report.log"

# Run linux-bench checks
echo "Starting CIS Linux Benchmark Check..."
linux-bench \
    --json \
    --outputfile "$CIS_LINUX_REPORT" \
    --include-test-output \
    --logtostderr \
    --config-dir ./cfg/

echo "Linux CIS Report generated at: $CIS_LINUX_REPORT"

# Run kube-bench checks
echo "Starting CIS Kubernetes Benchmark Check..."
kube-bench run \
    --json \
    --outputfile "$CIS_KUBE_REPORT" \
    --include-test-output \
    --logtostderr

echo "Kubernetes CIS Report generated at: $CIS_KUBE_REPORT"