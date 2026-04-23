#!/bin/bash
# Install MCP SearXNG Server
# This script installs the MCP server for SearXNG and configures it for use with Claude Desktop

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== MCP SearXNG Server Installation ==="
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed."
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

echo "Node.js version: $(node --version)"
echo ""

# Install dependencies
echo "Installing dependencies..."
cd "$SCRIPT_DIR"
npm install

echo ""
echo "Installation complete!"
echo ""

# Configure for Claude Desktop
echo "=== Configuring for Claude Desktop ==="
echo ""

# Determine the OS-specific config path
if [[ "$OSTYPE" == "darwin"* ]]; then
    CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CLAUDE_CONFIG_DIR="$HOME/.config/Claude"
else
    echo "Warning: Unknown OS type. Using default config path."
    CLAUDE_CONFIG_DIR="$HOME/.config/Claude"
fi

CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

echo "Claude Desktop config location: $CLAUDE_CONFIG_FILE"
echo ""

# Create config directory if it doesn't exist
mkdir -p "$CLAUDE_CONFIG_DIR"

# Create or update the config file
if [ -f "$CLAUDE_CONFIG_FILE" ]; then
    echo "Existing config found. Creating backup..."
    cp "$CLAUDE_CONFIG_FILE" "${CLAUDE_CONFIG_FILE}.bak"
fi

# Generate the MCP config
cat > "$CLAUDE_CONFIG_FILE" << EOF
{
  "mcpServers": {
    "searxng": {
      "command": "node",
      "args": ["${SCRIPT_DIR}/index.js"],
      "env": {
        "SEARXNG_BASE_URL": "http://localhost:8082"
      }
    }
  }
}
EOF

echo "Claude Desktop config updated successfully!"
echo ""
echo "=== Configuration ==="
cat "$CLAUDE_CONFIG_FILE"
echo ""
echo "=== Next Steps ==="
echo "1. Restart Claude Desktop to load the new MCP server"
echo "2. The SearXNG MCP server will be available as a tool"
echo ""
echo "Available tools:"
echo "  - searxng_search: Full search with category and engine options"
echo "  - searxng_search_simple: Quick formatted search results"
echo "  - searxng_news: Search news articles"
echo "  - searxng_images: Search images"
echo "  - searxng_videos: Search videos"
echo "  - searxng_engines: List available search engines"
echo "  - searxng_info: Get SearXNG instance info"
echo ""
echo "Environment variables (optional):"
echo "  SEARXNG_BASE_URL - SearXNG server URL (default: http://localhost:8082)"
echo "  SEARXNG_DEFAULT_RESULTS - Default result count (default: 10)"
echo "  SEARXNG_TIMEOUT - Request timeout in seconds (default: 10)"