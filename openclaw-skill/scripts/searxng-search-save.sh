#!/bin/bash
# SearXNG Search Script - Saves results to file
# Usage: searxng-search-save.sh "query" [output_file] [count]

QUERY="${1:-}"
OUTPUT_FILE="${2:-results.json}"
COUNT="${3:-10}"
SEARXNG_URL="${SEARXNG_URL:-http://localhost:8082}"

# Validate query
if [ -z "$QUERY" ]; then
    echo "Usage: searxng-search-save.sh \"search query\" [output_file] [count]" >&2
    echo "Example: searxng-search-save.sh \"docker compose\" results.json 20" >&2
    exit 1
fi

# URL encode the query
ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

# Make request with proper headers to bypass rate limiting
curl -s "${SEARXNG_URL}/search?q=${ENCODED_QUERY}&format=json&count=${COUNT}" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -H "User-Agent: Mozilla/5.0" \
    -H "Accept: application/json" \
    -o "${OUTPUT_FILE}"

if [ $? -eq 0 ]; then
    echo "Results saved to ${OUTPUT_FILE}"
    if command -v jq &> /dev/null; then
        echo "Number of results: $(jq '.results | length' "${OUTPUT_FILE}" 2>/dev/null || echo "N/A")"
    fi
else
    echo "Error fetching results" >&2
    exit 1
fi