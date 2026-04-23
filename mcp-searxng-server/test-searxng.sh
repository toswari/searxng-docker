#!/bin/bash
#
# Test script for SearXNG Search Functionality
# Tests various search queries against the SearXNG instance
# Outputs results in Markdown format to test-output directory
#

set -e

# Configuration
SEARXNG_HOST="${SEARXNG_HOST:-localhost}"
SEARXNG_PORT="${SEARXNG_PORT:-8082}"
BASE_URL="http://${SEARXNG_HOST}:${SEARXNG_PORT}"
OUTPUT_DIR="$(dirname "$0")/test-output"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate timestamp for output file
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="$OUTPUT_DIR/test-results-${TIMESTAMP}.md"

# Helper functions
print_test() {
    echo -e "${YELLOW}Testing: $1${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ PASS: $1${NC}"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL: $1${NC}"
    ((TESTS_FAILED++))
}

# Write to markdown output
write_md() {
    echo "$1" >> "$OUTPUT_FILE"
}

# Check if SearXNG is running
check_searxng() {
    print_test "Checking if SearXNG is running at ${BASE_URL}"
    if curl -s --connect-timeout 5 "${BASE_URL}/" > /dev/null 2>&1; then
        print_pass "SearXNG is running"
        return 0
    else
        print_fail "SearXNG is not responding"
        return 1
    fi
}

# Test 1: Basic text search
test_basic_search() {
    print_test "Basic search: 'open source software'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=open source software" \
        --data-urlencode "format=markdown" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Save raw response
    echo "$RESPONSE" > "$OUTPUT_DIR/basic_search.md"
    
    # Check for search results indicators
    if echo "$RESPONSE" | grep -qi "result\|search\|found"; then
        print_pass "Basic search returns results"
        write_md "### ✓ Basic Search: PASS"
        write_md "- Query: \`open source software\`"
        write_md "- Results saved to: \`basic_search.md\`"
        write_md ""
    else
        print_fail "Basic search returned no results"
        write_md "### ✗ Basic Search: FAIL"
        write_md "- Query: \`open source software\`"
        write_md ""
    fi
}

# Test 2: News search
test_news_search() {
    print_test "News search: 'technology news'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=technology news" \
        --data-urlencode "categories=news" \
        --data-urlencode "format=markdown" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Save raw response
    echo "$RESPONSE" > "$OUTPUT_DIR/news_search.md"
    
    # Check for news results
    if echo "$RESPONSE" | grep -qi "result\|news\|article\|story"; then
        print_pass "News search returns results"
        write_md "### ✓ News Search: PASS"
        write_md "- Query: \`technology news\`"
        write_md "- Category: \`news\`"
        write_md "- Results saved to: \`news_search.md\`"
        write_md ""
    else
        print_fail "News search returned no results"
        write_md "### ✗ News Search: FAIL"
        write_md "- Query: \`technology news\`"
        write_md ""
    fi
}

# Test 3: Image search
test_image_search() {
    print_test "Image search: 'nature landscape'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=nature landscape" \
        --data-urlencode "categories=images" \
        --data-urlencode "format=markdown" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Save raw response
    echo "$RESPONSE" > "$OUTPUT_DIR/image_search.md"
    
    # Check for image results
    if echo "$RESPONSE" | grep -qi "result\|image\|thumbnail\|img"; then
        print_pass "Image search returns results"
        write_md "### ✓ Image Search: PASS"
        write_md "- Query: \`nature landscape\`"
        write_md "- Category: \`images\`"
        write_md "- Results saved to: \`image_search.md\`"
        write_md ""
    else
        print_fail "Image search returned no results"
        write_md "### ✗ Image Search: FAIL"
        write_md "- Query: \`nature landscape\`"
        write_md ""
    fi
}

# Test 4: JSON API search
test_json_search() {
    print_test "JSON API search: 'artificial intelligence'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=artificial intelligence" \
        --data-urlencode "format=json" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Save raw response
    echo "$RESPONSE" > "$OUTPUT_DIR/json_search.json"
    
    # Check for JSON response with results
    if echo "$RESPONSE" | grep -q '"results"\|"query"'; then
        print_pass "JSON API search returns valid response"
        write_md "### ✓ JSON API Search: PASS"
        write_md "- Query: \`artificial intelligence\`"
        write_md "- Format: \`json\`"
        write_md "- Results saved to: \`json_search.json\`"
        write_md ""
    else
        print_fail "JSON API search returned invalid response"
        write_md "### ✗ JSON API Search: FAIL"
        write_md "- Query: \`artificial intelligence\`"
        write_md ""
    fi
}

# Test 5: Search with specific engine
test_engine_search() {
    print_test "Search with specific engine (google): 'weather forecast'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=weather forecast" \
        --data-urlencode "engines=google" \
        --data-urlencode "format=markdown" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Save raw response
    echo "$RESPONSE" > "$OUTPUT_DIR/engine_search.md"
    
    # Check for results
    if echo "$RESPONSE" | grep -qi "result\|weather\|forecast"; then
        print_pass "Engine-specific search returns results"
        write_md "### ✓ Engine-Specific Search: PASS"
        write_md "- Query: \`weather forecast\`"
        write_md "- Engine: \`google\`"
        write_md "- Results saved to: \`engine_search.md\`"
        write_md ""
    else
        print_fail "Engine-specific search returned no results"
        write_md "### ✗ Engine-Specific Search: FAIL"
        write_md "- Query: \`weather forecast\`"
        write_md ""
    fi
}

# Test 6: Video search
test_video_search() {
    print_test "Video search: 'tutorial programming'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=tutorial programming" \
        --data-urlencode "categories=videos" \
        --data-urlencode "format=markdown" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Save raw response
    echo "$RESPONSE" > "$OUTPUT_DIR/video_search.md"
    
    # Check for video results
    if echo "$RESPONSE" | grep -qi "result\|video\|watch\|youtube"; then
        print_pass "Video search returns results"
        write_md "### ✓ Video Search: PASS"
        write_md "- Query: \`tutorial programming\`"
        write_md "- Category: \`videos\`"
        write_md "- Results saved to: \`video_search.md\`"
        write_md ""
    else
        print_fail "Video search returned no results"
        write_md "### ✗ Video Search: FAIL"
        write_md "- Query: \`tutorial programming\`"
        write_md ""
    fi
}

# Test 7: Empty query handling
test_empty_query() {
    print_test "Empty query handling"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=" \
        --data-urlencode "format=markdown" \
        --connect-timeout 5 \
        --max-time 10)
    
    # Save raw response
    echo "$RESPONSE" > "$OUTPUT_DIR/empty_query.md"
    
    # Should return some response (error page or redirect)
    if [ -n "$RESPONSE" ]; then
        print_pass "Empty query handled gracefully"
        write_md "### ✓ Empty Query Handling: PASS"
        write_md "- Results saved to: \`empty_query.md\`"
        write_md ""
    else
        print_fail "Empty query caused error"
        write_md "### ✗ Empty Query Handling: FAIL"
        write_md ""
    fi
}

# Test 8: Special characters in query
test_special_characters() {
    print_test "Special characters: 'C++ programming'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=C++ programming" \
        --data-urlencode "format=markdown" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Save raw response
    echo "$RESPONSE" > "$OUTPUT_DIR/special_chars_search.md"
    
    # Check for results
    if echo "$RESPONSE" | grep -qi "result\|programming\|C++"; then
        print_pass "Special characters handled correctly"
        write_md "### ✓ Special Characters: PASS"
        write_md "- Query: \`C++ programming\`"
        write_md "- Results saved to: \`special_chars_search.md\`"
        write_md ""
    else
        print_fail "Special characters not handled"
        write_md "### ✗ Special Characters: FAIL"
        write_md "- Query: \`C++ programming\`"
        write_md ""
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "================================"
    echo "Test Summary"
    echo "================================"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
    echo "================================"
    
    # Write summary to markdown
    write_md "---"
    write_md ""
    write_md "## Summary"
    write_md ""
    write_md "| Metric | Value |"
    write_md "|--------|-------|"
    write_md "| Passed | $TESTS_PASSED |"
    write_md "| Failed | $TESTS_FAILED |"
    write_md "| Total  | $((TESTS_PASSED + TESTS_FAILED)) |"
    write_md ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        write_md "**Result:** All tests passed! ✓"
        write_md ""
        write_md "---"
        write_md "*Test completed at $(date)*"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        write_md "**Result:** Some tests failed. ✗"
        write_md ""
        write_md "---"
        write_md "*Test completed at $(date)*"
        exit 1
    fi
}

# Main
main() {
    # Initialize markdown file
    write_md "# SearXNG Search Test Results"
    write_md ""
    write_md "## Configuration"
    write_md ""
    write_md "| Setting | Value |"
    write_md "|---------|-------|"
    write_md "| Server | ${BASE_URL} |"
    write_md "| Date | $(date) |"
    write_md "| Output Directory | ${OUTPUT_DIR} |"
    write_md ""
    write_md "---"
    write_md ""
    write_md "## Test Results"
    write_md ""
    
    echo "================================"
    echo "SearXNG Search Test Suite"
    echo "================================"
    echo "Server: ${BASE_URL}"
    echo "Date:   $(date)"
    echo "Output: ${OUTPUT_DIR}"
    echo "================================"
    echo ""
    
    # Check SearXNG first
    if ! check_searxng; then
        echo ""
        echo -e "${RED}Error: SearXNG is not running at ${BASE_URL}${NC}"
        echo "Please ensure the SearXNG container is running:"
        echo "  docker-compose up -d"
        echo ""
        write_md ""
        write_md "## Error"
        write_md ""
        write_md "SearXNG is not running at ${BASE_URL}"
        write_md ""
        write_md "Please ensure the SearXNG container is running:"
        write_md '```bash'
        write_md "docker-compose up -d"
        write_md '```'
        exit 1
    fi
    
    echo ""
    
    # Run tests
    test_basic_search
    test_news_search
    test_image_search
    test_json_search
    test_engine_search
    test_video_search
    test_empty_query
    test_special_characters
    
    # Print summary
    print_summary
    
    echo ""
    echo "Results saved to: ${OUTPUT_FILE}"
}

# Run main
main "$@"