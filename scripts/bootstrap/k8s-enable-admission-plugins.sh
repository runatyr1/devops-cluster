#!/bin/bash
# Adds the MutatingAdmissionPolicy plugin to the enable-admission-plugins parameter.

set -x  # Enable command tracing

MANIFEST_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
#This is not working to add more than one param yet, see https://github.com/runatyr1/devops-cluster/issues/52
TARGET_PLUGIN="MutatingAdmissionPolicy" 
BACKUP_FILE="/root/kube-apiserver.yaml.bak"

echo "Starting script..."
echo "Manifest file: $MANIFEST_FILE"
echo "Target plugin: $TARGET_PLUGIN"

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

# Find the line with enable-admission-plugins
echo "Searching for existing enable-admission-plugins..."
plugins_line=$(grep -n '\--enable-admission-plugins=' "$MANIFEST_FILE" || true)
echo "Admission plugins line found: $plugins_line"

if [ -z "$plugins_line" ]; then
    echo "No existing enable-admission-plugins found. Adding new configuration..."
    
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
    
    # Insert the new enable-admission-plugins line
    sed -i "${line_number}a\\    - --enable-admission-plugins=${TARGET_PLUGIN}" "$MANIFEST_FILE"
    
    # Verify the change
    if grep -q "\--enable-admission-plugins=${TARGET_PLUGIN}" "$MANIFEST_FILE"; then
        echo "Successfully added enable-admission-plugins with $TARGET_PLUGIN"
    else
        echo "Error: Failed to add enable-admission-plugins"
        cp "$BACKUP_FILE" "$MANIFEST_FILE"
        exit 1
    fi
    exit 0
fi

# Extract the existing admission plugins
existing_plugins=$(echo "$plugins_line" | sed -n 's/.*--enable-admission-plugins=\([^[:space:]]*\).*/\1/p')
echo "Existing plugins: $existing_plugins"

# Check if the target plugin already exists
if echo "$existing_plugins" | grep -q "$TARGET_PLUGIN"; then
    echo "Target plugin already exists in enable-admission-plugins"
    exit 0
fi

# Append the new plugin to the existing plugins
updated_plugins="${existing_plugins},${TARGET_PLUGIN}"
echo "Updated plugins will be: $updated_plugins"

# Replace the entire line with updated plugins
line_number=$(echo "$plugins_line" | cut -d ':' -f1)
echo "Updating line number: $line_number"

sed -i "${line_number}s/--enable-admission-plugins=[^[:space:]]*/--enable-admission-plugins=${updated_plugins}/" "$MANIFEST_FILE"

# Verify the change
if grep -q "\--enable-admission-plugins=${updated_plugins}" "$MANIFEST_FILE"; then
    echo "Successfully updated enable-admission-plugins with $TARGET_PLUGIN"
else
    echo "Error: Failed to update enable-admission-plugins"
    cp "$BACKUP_FILE" "$MANIFEST_FILE"
    exit 1
fi

echo "Final manifest file contents:"
cat "$MANIFEST_FILE"