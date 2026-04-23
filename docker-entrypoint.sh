#!/bin/sh
# Docker entrypoint script that starts SearXNG with granian ASGI server

set -e

echo "Starting SearXNG with granian..."

# Use granian to run SearXNG (same as official image)
echo "Starting SearXNG on port 8080..."
exec /usr/local/searxng/.venv/bin/granian searx.webapp:app