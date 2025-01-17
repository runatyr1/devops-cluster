#!/bin/bash

AUDIT_POLICY_DIR="/etc/kubernetes/audit-policy"
AUDIT_POLICY_FILE="${AUDIT_POLICY_DIR}/policy.yaml"
APISERVER_CONFIG="/etc/kubernetes/manifests/kube-apiserver.yaml"
AUDIT_LOGS_DIR="/etc/kubernetes/audit-logs"



# Create required directories
mkdir -p "${AUDIT_POLICY_DIR}" "${AUDIT_LOGS_DIR}"

# Function to check if audit policy exists and is correct
setup_audit_policy() {
    if [[ -f "${AUDIT_POLICY_FILE}" ]]; then
        local current_policy=$(cat "${AUDIT_POLICY_FILE}")
        local required_policy="apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: \"\"
    resources: [\"secrets\"]
- level: RequestResponse
  userGroups: [\"system:nodes\"]
- level: None"
        
        if [[ "${current_policy}" == "${required_policy}" ]]; then
            echo "Audit policy already correctly configured"
            return 0
        fi
    fi
    
    echo "${required_policy}" > "${AUDIT_POLICY_FILE}"
    echo "Audit policy created/updated"
}

# Function to check if a YAML block exists
check_yaml_block() {
    local file=$1
    local check_content=$2
    local first_line=$(echo "$check_content" | head -n1 | sed 's/[][\.*^$/]/\\&/g')
    
    if grep -q "$first_line" "$file"; then
        return 0
    fi
    return 1
}

# Function to insert YAML block if it doesn't exist
insert_yaml_block() {
    local file=$1
    local marker=$2
    local content=$3
    local temp_file=$(mktemp)

    if ! check_yaml_block "${file}" "${content}"; then
        awk -v marker="${marker}" -v block="${content}" '
        $0 ~ marker {
            print $0
            if ($0 ~ /^[[:space:]]*volumes:/) {
                print block
            } else if ($0 ~ /^[[:space:]]*volumeMounts:/) {
                print block
            } else if ($0 ~ /kube-apiserver/) {
                getline
                print $0
                print block
            }
            next
        }
        { print }
        ' "${file}" > "${temp_file}"
        mv "${temp_file}" "${file}"
        echo "Updated ${marker} configuration"
    else
        echo "Configuration for ${marker} already exists"
        rm -f "${temp_file}"
    fi
}

# Update API server configuration
update_apiserver_config() {
    # Volumes configuration
    local volumes_block="  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit-policy/policy.yaml
      type: File
  - name: audit-logs
    hostPath:
      path: /etc/kubernetes/audit-logs
      type: DirectoryOrCreate"

    # Volume mounts configuration
    local mounts_block="    - mountPath: /etc/kubernetes/audit-policy/policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /etc/kubernetes/audit-logs
      name: audit-logs
      readOnly: false"

    # Command parameters
    local params="    - --audit-policy-file=/etc/kubernetes/audit-policy/policy.yaml
    - --audit-log-path=/etc/kubernetes/audit-logs/audit.log
    - --audit-log-maxsize=7
    - --audit-log-maxbackup=2"

    # Insert configurations with proper section markers
    insert_yaml_block "${APISERVER_CONFIG}" "^[[:space:]]*volumes:" "${volumes_block}"
    insert_yaml_block "${APISERVER_CONFIG}" "^[[:space:]]*volumeMounts:" "${mounts_block}"
    insert_yaml_block "${APISERVER_CONFIG}" "- kube-apiserver" "${params}"
}

# Main execution
setup_audit_policy
update_apiserver_config

# Verify configuration
if [[ -f "${AUDIT_POLICY_FILE}" ]] && grep -q "audit-policy-file" "${APISERVER_CONFIG}"; then
    echo "Target config already exists"
    exit 0
else
    echo "Configuration verification failed"
    exit 1
fi