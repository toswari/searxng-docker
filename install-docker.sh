#!/bin/bash

# Docker Installation Script for SearXNG with MCP Server
# This script installs Docker and Docker Compose, then starts the SearXNG service with MCP server

set -e

echo "=== SearXNG Docker Installation Script ==="

# Detect OS and package manager
if [ "$(uname)" = "Darwin" ]; then
    OS="macos"
    if command -v brew &> /dev/null; then
        PKG_MANAGER="brew"
    else
        echo "Homebrew is not installed. Please install Homebrew first: https://brew.sh"
        exit 1
    fi
elif command -v apt-get &> /dev/null; then
    OS="linux"
    PKG_MANAGER="apt-get"
elif command -v yum &> /dev/null; then
    OS="linux"
    PKG_MANAGER="yum"
elif command -v dnf &> /dev/null; then
    OS="linux"
    PKG_MANAGER="dnf"
elif command -v pacman &> /dev/null; then
    OS="linux"
    PKG_MANAGER="pacman"
else
    echo "Unsupported package manager"
    exit 1
fi

echo "Detected OS: $OS"
echo "Detected package manager: $PKG_MANAGER"

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    
    if [ "$PKG_MANAGER" = "brew" ]; then
        brew update
        brew install --cask docker
    elif [ "$PKG_MANAGER" = "apt-get" ]; then
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        pacman -Syu --noconfirm docker docker-compose
    fi
else
    echo "Docker is already installed"
fi

# Start Docker service if not running
if [ "$OS" = "macos" ]; then
    echo "Starting Docker Desktop..."
    open -a Docker
    echo "Waiting for Docker Desktop to start (this may take a minute)..."
    while ! docker info &> /dev/null; do
        sleep 5
    done
elif command -v systemctl &> /dev/null; then
    if ! systemctl is-active --quiet docker; then
        echo "Starting Docker service..."
        systemctl start docker
        systemctl enable docker
    fi
fi

# Add current user to docker group (Linux only)
if [ "$OS" = "linux" ] && [ -n "$SUDO_USER" ]; then
    echo "Adding user to docker group..."
    usermod -aG docker $SUDO_USER
fi

# Verify Docker installation
echo "Verifying Docker installation..."
docker --version
docker compose version

# Pull and start SearXNG with MCP server
echo "Building SearXNG image with MCP server..."
docker compose build

echo "Starting SearXNG service with MCP server..."
docker compose up -d

echo ""
echo "=== Docker Installation Complete ==="
echo "SearXNG is now running on http://localhost:8082"
echo "MCP server is running inside the container on port 8081"
echo ""
echo "To check the status: docker compose ps"
echo "To view logs: docker compose logs -f"
echo "To stop: docker compose down"

# Install MCP server for Claude Desktop integration
echo ""
echo "=== Installing MCP Server for Claude Desktop ==="

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    if [ "$PKG_MANAGER" = "brew" ]; then
        brew install node
    elif [ "$PKG_MANAGER" = "apt-get" ]; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
        apt-get install -y nodejs
    elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
        yum install -y nodejs
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        pacman -Syu --noconfirm nodejs npm
    fi
fi

# Install MCP server dependencies
echo "Installing MCP server dependencies..."
cd "$(dirname "$0")/mcp-searxng-server"
npm install --production

# Configure Claude Desktop
echo ""
echo "Configuring Claude Desktop for MCP server..."

CLAUDE_CONFIG_DIR=""
if [ "$OS" = "macos" ]; then
    CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
elif [ "$OS" = "linux" ]; then
    CLAUDE_CONFIG_DIR="$HOME/.config/Claude"
fi

if [ -n "$CLAUDE_CONFIG_DIR" ]; then
    mkdir -p "$CLAUDE_CONFIG_DIR"
    
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    MCP_SERVER_PATH="$SCRIPT_DIR/mcp-searxng-server"
    SEARXNG_URL="http://localhost:8082"
    
    cat > "$CLAUDE_CONFIG_DIR/claude_desktop_config.json" << EOF
{
  "mcpServers": {
    "searxng": {
      "command": "node",
      "args": ["$MCP_SERVER_PATH/index.js"],
      "env": {
        "SEARXNG_BASE_URL": "$SEARXNG_URL",
        "SEARXNG_DEFAULT_RESULTS": "10",
        "SEARXNG_TIMEOUT": "10"
      }
    }
  }
}
EOF
    
    echo "Claude Desktop configuration created at: $CLAUDE_CONFIG_DIR/claude_desktop_config.json"
    echo ""
    echo "=== MCP Server Installation Complete ==="
    echo "Restart Claude Desktop to use the MCP server"
else
    echo "Could not find Claude Desktop config directory."
    echo "Manual configuration may be required."
fi

echo ""
echo "=== All Installation Complete ==="
echo "SearXNG web interface: http://localhost:8082"
echo "MCP server: Available in Claude Desktop after restart"