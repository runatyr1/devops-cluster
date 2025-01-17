#!/bin/bash
# Adds the --runtime-config api group specified to the config.

set -x  # Enable command tracing

MANIFEST_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
TARGET_CONFIG="admissionregistration.k8s.io/v1alpha1"
BACKUP_FILE="/root/kube-apiserver.yaml.bak"

echo "Starting script..."
echo "Manifest file: $MANIFEST_FILE"
echo "Target config: $TARGET_CONFIG"

# Check if the file exists and is readable
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

if [ ! -r "$MANIFEST_FILE" ]; then
    echo "Error: Cannot read manifest file: $MANIFEST_FILE"
    exit 1
fi

# Create backup before any modifications
cp "$MANIFEST_FILE" "$BACKUP_FILE"

# Output file contents for debugging
echo "Current manifest file contents:"
cat "$MANIFEST_FILE"

# Find the line with runtime-config
echo "Searching for existing runtime-config..."
runtime_config_line=$(grep -n '\--runtime-config=' "$MANIFEST_FILE" || true)
echo "Runtime config line found: $runtime_config_line"

if [ -z "$runtime_config_line" ]; then
    echo "No existing runtime-config found. Adding new configuration..."
    
    # Find the kube-apiserver line
    kube_apiserver_line=$(grep -n "    - kube-apiserver" "$MANIFEST_FILE" || true)
    echo "Kube-apiserver line found: $kube_apiserver_line"
    
    if [ -z "$kube_apiserver_line" ]; then
        echo "Error: Could not find kube-apiserver line in manifest"
        cp "$BACKUP_FILE" "$MANIFEST_FILE"
        exit 1
    fi
    
    line_number=$(echo "$kube_apiserver_line" | cut -d ':' -f1)
    echo "Inserting at line number: $line_number"
    
    # Insert the new runtime-config line
    sed -i "${line_number}a\\    - --runtime-config=${TARGET_CONFIG}" "$MANIFEST_FILE"
    
    # Verify the change
    if grep -q "\--runtime-config=${TARGET_CONFIG}" "$MANIFEST_FILE"; then
        echo "Successfully added runtime-config with $TARGET_CONFIG"
    else
        echo "Error: Failed to add runtime-config"
        cp "$BACKUP_FILE" "$MANIFEST_FILE"
        exit 1
    fi
    exit 0
fi

# Extract the existing runtime-config options
existing_config=$(echo "$runtime_config_line" | sed -n 's/.*--runtime-config=\([^[:space:]]*\).*/\1/p')
echo "Existing config: $existing_config"

# Check if the target config already exists
if echo "$existing_config" | grep -q "$TARGET_CONFIG"; then
    echo "Target config already exists in runtime-config"
    exit 0
fi

# Append the new config to the existing configs
updated_config="${existing_config},${TARGET_CONFIG}"
echo "Updated config will be: $updated_config"

# Replace the entire line with updated config
line_number=$(echo "$runtime_config_line" | cut -d ':' -f1)
echo "Updating line number: $line_number"

sed -i "${line_number}s/--runtime-config=[^[:space:]]*/--runtime-config=${updated_config}/" "$MANIFEST_FILE"

# Verify the change
if grep -q "\--runtime-config=${updated_config}" "$MANIFEST_FILE"; then
    echo "Successfully updated runtime-config with $TARGET_CONFIG"
else
    echo "Error: Failed to update runtime-config"
    cp "$BACKUP_FILE" "$MANIFEST_FILE"
    exit 1
fi

echo "Final manifest file contents:"
cat "$MANIFEST_FILE"