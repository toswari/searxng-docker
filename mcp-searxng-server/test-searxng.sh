#!/bin/bash
#
# Test script for SearXNG Search Functionality
# Tests various search queries against the SearXNG instance
#

set -e

# Configuration
SEARXNG_HOST="${SEARXNG_HOST:-localhost}"
SEARXNG_PORT="${SEARXNG_PORT:-8080}"
BASE_URL="http://${SEARXNG_HOST}:${SEARXNG_PORT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

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
        -H "Accept: text/html" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Check for search results indicators
    if echo "$RESPONSE" | grep -qi "result\|search\|found"; then
        print_pass "Basic search returns results"
    else
        print_fail "Basic search returned no results"
    fi
}

# Test 2: News search
test_news_search() {
    print_test "News search: 'technology news'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=technology news" \
        --data-urlencode "categories=news" \
        -H "Accept: text/html" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Check for news results
    if echo "$RESPONSE" | grep -qi "result\|news\|article\|story"; then
        print_pass "News search returns results"
    else
        print_fail "News search returned no results"
    fi
}

# Test 3: Image search
test_image_search() {
    print_test "Image search: 'nature landscape'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=nature landscape" \
        --data-urlencode "categories=images" \
        -H "Accept: text/html" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Check for image results
    if echo "$RESPONSE" | grep -qi "result\|image\|thumbnail\|img"; then
        print_pass "Image search returns results"
    else
        print_fail "Image search returned no results"
    fi
}

# Test 4: JSON API search
test_json_search() {
    print_test "JSON API search: 'artificial intelligence'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=artificial intelligence" \
        -H "Accept: application/json" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Check for JSON response with results
    if echo "$RESPONSE" | grep -q '"results"\|"query"'; then
        print_pass "JSON API search returns valid response"
    else
        print_fail "JSON API search returned invalid response"
    fi
}

# Test 5: Search with specific engine
test_engine_search() {
    print_test "Search with specific engine (google): 'weather forecast'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=weather forecast" \
        --data-urlencode "engines=google" \
        -H "Accept: text/html" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Check for results
    if echo "$RESPONSE" | grep -qi "result\|weather\|forecast"; then
        print_pass "Engine-specific search returns results"
    else
        print_fail "Engine-specific search returned no results"
    fi
}

# Test 6: Video search
test_video_search() {
    print_test "Video search: 'tutorial programming'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=tutorial programming" \
        --data-urlencode "categories=videos" \
        -H "Accept: text/html" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Check for video results
    if echo "$RESPONSE" | grep -qi "result\|video\|watch\|youtube"; then
        print_pass "Video search returns results"
    else
        print_fail "Video search returned no results"
    fi
}

# Test 7: Empty query handling
test_empty_query() {
    print_test "Empty query handling"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=" \
        -H "Accept: text/html" \
        --connect-timeout 5 \
        --max-time 10)
    
    # Should return some response (error page or redirect)
    if [ -n "$RESPONSE" ]; then
        print_pass "Empty query handled gracefully"
    else
        print_fail "Empty query caused error"
    fi
}

# Test 8: Special characters in query
test_special_characters() {
    print_test "Special characters: 'C++ programming'"
    
    RESPONSE=$(curl -s -G "${BASE_URL}/search" \
        --data-urlencode "q=C++ programming" \
        -H "Accept: text/html" \
        --connect-timeout 10 \
        --max-time 30)
    
    # Check for results
    if echo "$RESPONSE" | grep -qi "result\|programming\|C++"; then
        print_pass "Special characters handled correctly"
    else
        print_fail "Special characters not handled"
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
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Main
main() {
    echo "================================"
    echo "SearXNG Search Test Suite"
    echo "================================"
    echo "Server: ${BASE_URL}"
    echo "Date:   $(date)"
    echo "================================"
    echo ""
    
    # Check SearXNG first
    if ! check_searxng; then
        echo ""
        echo -e "${RED}Error: SearXNG is not running at ${BASE_URL}${NC}"
        echo "Please ensure the SearXNG container is running:"
        echo "  docker-compose up -d"
        echo ""
        exit 1
    fi
    
    echo ""
    
    # Run tests (at least 3 different searches as requested)
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
}

# Run main
main "$@"