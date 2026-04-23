#!/bin/sh
# Docker entrypoint script that starts SearXNG
# Uses granian ASGI server like the official image

set -e

echo "Starting SearXNG with granian..."

# Use granian to run SearXNG (same as official image)
exec /usr/local/searxng/.venv/bin/granian searx.webapp:app