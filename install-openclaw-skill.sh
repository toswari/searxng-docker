#!/bin/bash
# Install SearXNG Search Skill for OpenClaw
# This script copies the searxng-search skill to the OpenClaw skills directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_SKILL_DIR="${HOME}/.openclaw/skills/searxng-search"

echo "Installing searxng-search skill to OpenClaw..."

# Create the target directory if it doesn't exist
mkdir -p "${OPENCLAW_SKILL_DIR}/scripts"

# Copy SKILL.md
echo "Copying SKILL.md..."
cp "${SCRIPT_DIR}/openclaw-skill/SKILL.md" "${OPENCLAW_SKILL_DIR}/SKILL.md"

# Copy scripts
echo "Copying scripts..."
cp "${SCRIPT_DIR}/openclaw-skill/scripts/searxng-search.sh" "${OPENCLAW_SKILL_DIR}/scripts/searxng-search.sh"
cp "${SCRIPT_DIR}/openclaw-skill/scripts/searxng-search-save.sh" "${OPENCLAW_SKILL_DIR}/scripts/searxng-search-save.sh"

# Make scripts executable
echo "Setting executable permissions..."
chmod +x "${OPENCLAW_SKILL_DIR}/scripts/searxng-search.sh"
chmod +x "${OPENCLAW_SKILL_DIR}/scripts/searxng-search-save.sh"

echo ""
echo "✓ searxng-search skill installed successfully!"
echo ""
echo "Skill location: ${OPENCLAW_SKILL_DIR}"
echo ""
echo "Usage:"
echo "  # Search and output to stdout"
echo "  ${OPENCLAW_SKILL_DIR}/scripts/searxng-search.sh \"your query\""
echo ""
echo "  # Search and save to file"
echo "  ${OPENCLAW_SKILL_DIR}/scripts/searxng-search-save.sh \"your query\" results.json"
echo ""
echo "Prerequisites:"
echo "  - SearXNG container running on port 8082"
echo "  - jq installed for JSON processing"
echo ""