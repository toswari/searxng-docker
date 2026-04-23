#!/bin/sh
# Docker entrypoint script that starts both SearXNG and MCP server

set -e

echo "Starting SearXNG and MCP server..."

# Start MCP server in background
echo "Starting MCP SearXNG server on port 8081..."
cd /opt/mcp-searxng
node index.js &
MCP_PID=$!

# Wait a moment for MCP server to start
sleep 2

# Start SearXNG
echo "Starting SearXNG..."
exec /sbin/tini -- python -m searxng