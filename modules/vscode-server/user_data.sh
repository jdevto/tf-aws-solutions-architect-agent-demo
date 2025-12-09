#!/bin/bash
# User data script for VS Code Server on EC2
# Compatible with Amazon Linux 2023

set -euo pipefail

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user data script execution..."

# Variables
VSCODE_PORT=${vscode_port}
TOKEN_PARAM=${token_param}
S3_BUCKET_NAME=${s3_bucket_name}

echo "Configuration:"
echo "  VS Code Server Port: $${VSCODE_PORT}"
echo "  SSM Parameter: $${TOKEN_PARAM}"
echo "  AWS Region: ${region}"
echo "  S3 Bucket Name: $${S3_BUCKET_NAME:-not configured}"

echo ""
echo "Setting up SSM Agent..."
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_ssm_agent.sh) install

# Update system
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y wget tar gzip unzip net-tools fuse fuse-devel libcurl-devel libxml2-devel openssl-devel git gcc gcc-c++ make

bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_aws_cli.sh) install

# Generate VS Code Server token
echo ""
echo "Generating VS Code Server authentication token..."
VSCODE_TOKEN=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "Token generated successfully"

# Store token in SSM Parameter Store
echo "Storing token in SSM Parameter Store: $${TOKEN_PARAM}"
if aws ssm put-parameter \
    --name "$${TOKEN_PARAM}" \
    --value "$${VSCODE_TOKEN}" \
    --type "SecureString" \
    --region "${region}" \
    --overwrite; then
    echo "Token stored in SSM Parameter Store successfully"
else
    echo "Warning: Failed to store token in SSM Parameter Store"
fi

# Install VS Code Server
echo ""
echo "Installing VS Code Server..."
VSCODE_SERVER_PORT=$${VSCODE_PORT} VSCODE_TOKEN=$${VSCODE_TOKEN} VSCODE_THEME="${vscode_theme}" bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_vscode_server.sh) install

# =============================================================================
# S3 MOUNT SETUP (if bucket name is provided)
# =============================================================================

if [ -n "$${S3_BUCKET_NAME}" ]; then
    echo ""
    echo "Setting up S3 mount for bucket: $${S3_BUCKET_NAME}"

    # Detect the user for mount ownership
    # Try to find a non-root user, default to ec2-user for Amazon Linux
    if id ec2-user &>/dev/null; then
        MOUNT_USER="ec2-user"
    elif id ubuntu &>/dev/null; then
        MOUNT_USER="ubuntu"
    elif [ -n "$SUDO_USER" ]; then
        MOUNT_USER="$SUDO_USER"
    else
        # Try to find any non-root user
        MOUNT_USER=$(getent passwd 2>/dev/null | awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}')
        if [ -z "$MOUNT_USER" ]; then
            echo "Error: Could not detect a non-root user for S3 mount"
            exit 1
        fi
    fi

    # Set mount point (default matches remote script default)
    MOUNT_POINT="/mnt/s3_config"

    echo "Using user for S3 mount: $${MOUNT_USER}"
    echo "Mount point: $${MOUNT_POINT}"
    S3_BUCKET_NAME=$${S3_BUCKET_NAME} MOUNT_USER=$${MOUNT_USER} MOUNT_POINT=$${MOUNT_POINT} bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_s3_mount.sh) install
else
    echo ""
    echo "S3 bucket not configured, skipping S3 mount setup"
fi

echo ""
echo "=== User data script completed successfully ==="
echo "VS Code Server is configured on port ${vscode_port}"
echo "Token stored in SSM Parameter: ${token_param}"
echo "You can retrieve the token with:"
echo "  aws ssm get-parameter --name ${token_param} --with-decryption --query 'Parameter.Value' --output text"
if [ -n "$${S3_BUCKET_NAME}" ]; then
    echo ""
    echo "S3 bucket $${S3_BUCKET_NAME} is mounted at $${MOUNT_POINT}"
fi
