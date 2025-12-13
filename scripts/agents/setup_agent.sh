#!/bin/bash

# AWS Solutions Architect Agent Setup Script
# Based on: https://dunlop.geek.nz/building-an-aws-solutions-architect-agent-with-strands-lm-studio-and-mcp-tools/

set -e

echo "=========================================="
echo "AWS Solutions Architect Agent Setup"
echo "=========================================="
echo ""

# Install Python 3.13
PYTHON_VERSION=3.13 bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_python.sh) install

# Check Python version (strands-agents requires Python >= 3.10)
echo "Checking Python version..."

# Try to find the correct Python version (prefer python3.13, then python3.12, etc., then python3)
PYTHON_CMD=""
for py_cmd in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$py_cmd" &> /dev/null; then
        PYTHON_VERSION=$("$py_cmd" --version 2>&1 | cut -d' ' -f2)
        PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
        PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

        # Check if version is >= 3.10
        if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 10 ]; then
            PYTHON_CMD="$py_cmd"
            echo "Found Python $PYTHON_VERSION at: $PYTHON_CMD"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "Error: Python 3.10 or higher is not installed or not found in PATH."
    echo "Please install Python 3.10 or higher."
    exit 1
fi

# Verify the version meets requirements
PYTHON_VERSION=$("$PYTHON_CMD" --version 2>&1 | cut -d' ' -f2)
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

echo "Using Python version: $PYTHON_VERSION"

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
    echo "Error: Python 3.10 or higher is required (strands-agents dependency)."
    echo "Current version: $PYTHON_VERSION"
    echo "Please upgrade Python to 3.10 or higher."
    exit 1
fi

# Export PYTHON_CMD for use in the rest of the script
export PYTHON_CMD
echo ""

# Install uv (Python package manager, written in Rust for speed, also used by MCP) if not already installed
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_uv.sh) install

# Ensure uv is in PATH for the rest of this script (install_uv.sh runs in subshell)
for bin_dir in "$HOME/.cargo/bin" "$HOME/.local/bin"; do
    [ -d "$bin_dir" ] && [[ ":$PATH:" != *":$bin_dir:"* ]] && export PATH="$bin_dir:$PATH"
done

# Verify uv is available and get full path (needed for sudo which resets PATH)
if ! UV_CMD=$(command -v uv 2>/dev/null); then
    echo "Error: uv installation completed but binary not found in PATH"
    exit 1
fi
echo ""

# Determine working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script location: $SCRIPT_DIR"

# Check if current directory is writable (S3 mounts are read-only)
if [ -w "$SCRIPT_DIR" ] 2>/dev/null && touch "$SCRIPT_DIR/.write_test" 2>/dev/null; then
    rm -f "$SCRIPT_DIR/.write_test" 2>/dev/null
    WORK_DIR="$SCRIPT_DIR"
    echo "Working directory: $WORK_DIR (writable)"
else
    # Use home directory if script directory is read-only (S3 mount)
    WORK_DIR="$HOME/agents"
    mkdir -p "$WORK_DIR"
    echo "Script directory is read-only (S3 mount). Using: $WORK_DIR"
    echo "Working directory: $WORK_DIR"
fi

cd "$WORK_DIR"
echo ""

# Install Python dependencies using uv (uv pip is uv's pip-compatible interface)
echo "Installing Python dependencies..."
# Get full path to Python command for uv
PYTHON_FULL_PATH=$(command -v "$PYTHON_CMD" 2>/dev/null || echo "$PYTHON_CMD")

if sudo -n true 2>/dev/null || [ "$EUID" -eq 0 ]; then
    echo "Installing packages system-wide with sudo..."
    if [ -f "requirements.txt" ]; then
        sudo env UV_PYTHON="$PYTHON_FULL_PATH" "$UV_CMD" pip install --system -r requirements.txt
    else
        echo "requirements.txt not found. Installing packages directly..."
        sudo env UV_PYTHON="$PYTHON_FULL_PATH" "$UV_CMD" pip install --system strands-agents openai mcp
    fi
else
    echo "Installing packages to user directory (no sudo access)..."
    if [ -f "requirements.txt" ]; then
        UV_PYTHON="$PYTHON_FULL_PATH" "$UV_CMD" pip install --user -r requirements.txt
    else
        echo "requirements.txt not found. Installing packages directly..."
        UV_PYTHON="$PYTHON_FULL_PATH" "$UV_CMD" pip install --user strands-agents openai mcp
    fi
fi
echo ""

# Create requirements.txt if it doesn't exist
if [ ! -f "requirements.txt" ]; then
    echo "Creating requirements.txt..."
    cat > requirements.txt << EOF
strands-agents>=0.1.0
openai>=1.0.0
mcp>=0.1.0
EOF
    echo "requirements.txt created!"
fi
echo ""

# Install LM Studio
echo ""
echo "Installing LM Studio..."
if bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_lm_studio.sh) install; then
    echo "LM Studio installed successfully"
else
    echo "Warning: LM Studio installation failed. You can install it manually later."
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Agent files are available in: $WORK_DIR"
echo ""
echo "Next steps:"
echo "1. Start the LM Studio service:"
echo "   sudo systemctl start lm-studio"
echo ""
echo "2. Download and load a model (recommended: Llama 3.1 8B or Mistral 7B):"
echo "   lms get \"Llama 3.1 8B Instruct\""
echo "   lms load meta-llama-3.1-8b-instruct"
echo ""
echo "3. Run one of the agents (from $WORK_DIR directory):"
echo "   cd $WORK_DIR"
echo "   - Basic agent: $PYTHON_CMD strands_agent.py"
echo "   - AWS Architect (custom tools): $PYTHON_CMD aws_architect_agent.py"
echo "   - AWS Architect (MCP only): $PYTHON_CMD aws_architect_mcp.py"
echo "   - AWS Architect (full): $PYTHON_CMD aws_architect_full.py"
echo ""
echo "For more information, see:"
echo "https://dunlop.geek.nz/building-an-aws-solutions-architect-agent-with-strands-lm-studio-and-mcp-tools/"
echo ""
