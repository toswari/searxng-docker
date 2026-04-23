#!/bin/bash
# Script to query searXNG and save JSON results

QUERY="${1:-docker}"
OUTPUT_FILE="${2:-results.json}"
SEARXNG_URL="${SEARXNG_URL:-http://localhost:8082}"

# Make request with proper headers to bypass rate limiting
curl -s "${SEARXNG_URL}/search?q=${QUERY}&format=json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -H "User-Agent: Mozilla/5.0" \
  -H "Accept: application/json" \
  -o "${OUTPUT_FILE}"

if [ $? -eq 0 ]; then
  echo "Results saved to ${OUTPUT_FILE}"
  echo "Number of results: $(jq '.results | length' ${OUTPUT_FILE})"
else
  echo "Error fetching results"
  exit 1
fi
