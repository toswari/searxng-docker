#!/bin/bash
# SearXNG Search Script - Returns JSON results
# Usage: searxng-search.sh "query" [count]

QUERY="${1:-}"
COUNT="${2:-10}"
SEARXNG_URL="${SEARXNG_URL:-http://localhost:8082}"

# Validate query
if [ -z "$QUERY" ]; then
    echo "Usage: searxng-search.sh \"search query\" [count]" >&2
    echo "Example: searxng-search.sh \"docker compose\" 20" >&2
    exit 1
fi

# URL encode the query
ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

# Make request with proper headers
curl -s "${SEARXNG_URL}/search?q=${ENCODED_QUERY}&format=json&count=${COUNT}" \
    -H "X-Forwarded-For: 127.0.0.1" \
    -H "User-Agent: Mozilla/5.0" \
    -H "Accept: application/json"

exit $?