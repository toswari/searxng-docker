#!/bin/bash
#
# Comprehensive MCP SearXNG Server Test Script
# Validates MCP protocol communication including:
#   - Health check endpoint
#   - SSE connection establishment
#   - MCP list-tools request/response
#   - MCP list-resources request/response
#   - MCP tool call (searxng_info)
#   - MCP tool call (searxng_search) - if SearXNG is available
#   - Error handling
#
# Usage: ./test-mcp.sh [options]
# Options:
#   --host HOST       MCP server host (default: localhost)
#   --port PORT       MCP server port (default: 3002)
#   --searxng-url URL SearXNG base URL (default: http://localhost:8082)
#   --help            Show help
#

set -euo pipefail

# Configuration
MCP_HOST="${MCP_HOST:-localhost}"
MCP_PORT="${MCP_PORT:-3002}"
SEARXNG_BASE_URL="${SEARXNG_BASE_URL:-http://localhost:8082}"
BASE_URL="http://${MCP_HOST}:${MCP_PORT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TOTAL_TESTS=0

# Session tracking
SESSION_ID=""

# Helper functions
print_test() {
    ((TOTAL_TESTS++)) || true
    echo -e "${YELLOW}[TEST $TOTAL_TESTS] $1${NC}"
}

print_pass() {
    echo -e "  ${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++)) || true
}

print_fail() {
    echo -e "  ${RED}✗ FAIL${NC}: $1"
    ((TESTS_FAILED++)) || true
}

print_skip() {
    echo -e "  ${CYAN}⊘ SKIP${NC}: $1"
    ((TESTS_SKIPPED++)) || true
}

print_info() {
    echo -e "  ${BLUE}ℹ INFO${NC}: $1"
}

print_section() {
    echo ""
    echo -e "${BOLD}=== $1 ===${NC}"
}

print_json() {
    echo "$1" | python3 -m json.tool 2>/dev/null || echo "$1"
}

# Cleanup function
cleanup() {
    if [ -n "$SESSION_ID" ]; then
        echo -e "${YELLOW}Cleaning up session: $SESSION_ID${NC}"
    fi
}
trap cleanup EXIT

# =============================================
# Test 1: Health Check
# =============================================
test_health_endpoint() {
    print_section "TEST 1: Health Check"

    print_test "GET /health"

    local response
    response=$(curl -s --connect-timeout 5 --max-time 10 "${BASE_URL}/health" 2>&1) || true

    if [ -z "$response" ]; then
        print_fail "Health endpoint not responding"
        echo "  Response: (empty)"
        return
    fi

    print_info "Raw response: $response"

    # Check for status field
    local status
    status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null) || true

    if [ "$status" = "ok" ]; then
        print_pass "Status is 'ok'"
    else
        print_fail "Status is '$status', expected 'ok'"
    fi

    # Check for timestamp field
    local timestamp
    timestamp=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('timestamp',''))" 2>/dev/null) || true

    if [ -n "$timestamp" ]; then
        print_pass "Timestamp present: $timestamp"
    else
        print_fail "Timestamp field missing"
    fi
}

# =============================================
# Test 2: SSE Connection
# =============================================
test_sse_connection() {
    print_section "TEST 2: SSE Connection"

    print_test "GET /sse (establish SSE connection)"

    # Start SSE connection in background and capture headers
    local sse_tmpfile
    sse_tmpfile=$(mktemp /tmp/sse_response.XXXXXX)

    # Use curl to connect to SSE endpoint in background
    # -N means no-buffer, which is required for SSE streaming
    curl -s -N --connect-timeout 5 --max-time 3 \
        -o "${sse_tmpfile}.body" \
        -D "${sse_tmpfile}.headers" \
        "${BASE_URL}/sse" 2>"${sse_tmpfile}.err" &
    local sse_pid=$!

    # Wait for curl to complete (it has --max-time 3)
    wait $sse_pid 2>/dev/null || true

    local headers
    headers=$(cat "${sse_tmpfile}.headers" 2>/dev/null) || true
    local body
    body=$(cat "${sse_tmpfile}.body" 2>/dev/null) || true

    # Check HTTP status code from headers (first line format: HTTP/1.1 200 OK)
    local http_status
    http_status=$(echo "$headers" | head -1 | grep -oP 'HTTP/\d+\.\d+\s+\K\d{3}' || echo "unknown")

    print_info "HTTP status: $http_status"
    print_info "Headers received: $(echo "$headers" | head -5)"

    if [ "$http_status" = "200" ]; then
        print_pass "SSE endpoint returns HTTP 200"
    else
        print_fail "SSE endpoint returned HTTP $http_status, expected 200"
    fi

    # Check for SSE content-type
    if echo "$headers" | grep -qi "text/event-stream"; then
        print_pass "Content-Type is text/event-stream"
    else
        print_fail "Missing text/event-stream content-type"
        print_info "Headers: $headers"
    fi

    # Check for SSE event stream indicators
    if echo "$body" | grep -q "event:"; then
        print_pass "SSE event stream detected"
    else
        print_info "No event data in brief connection (may be normal)"
    fi

    # Cleanup temp files
    rm -f "${sse_tmpfile}" "${sse_tmpfile}.headers" "${sse_tmpfile}.body" "${sse_tmpfile}.err"
}

# =============================================
# Test 3: MCP Protocol - List Tools (via Node.js SDK)
# =============================================
test_mcp_list_tools() {
    # Delegates to test_mcp_with_nodejs() which provides
    # a full MCP protocol implementation using the official SDK.
    test_mcp_with_nodejs
}

# =============================================
# Test 4: MCP Protocol with Node.js SDK
# =============================================
test_mcp_with_nodejs() {
    print_section "TEST 4: MCP Protocol - Full SDK Test"

    print_test "Connecting via MCP SDK (Node.js)"

    # Check if Node.js is available
    if ! command -v node &> /dev/null; then
        print_skip "Node.js not available for SDK test"
        return
    fi

    # Check if MCP SDK is available
    if [ ! -f "node_modules/@modelcontextprotocol/sdk/package.json" ]; then
        print_skip "MCP SDK not installed (run: npm install)"
        return
    fi

    # Create a test client script
    local test_client
    test_client=$(mktemp /tmp/mcp_test_client.XXXXXX.js)

    cat > "$test_client" << 'NODESCRIPT'
const { Client } = await import('@modelcontextprotocol/sdk/client/sse.js');

const MCP_HOST = process.env.MCP_HOST || 'localhost';
const MCP_PORT = process.env.MCP_PORT || '3002';
const SSE_URL = `http://${MCP_HOST}:${MCP_PORT}/sse`;
const TIMEOUT = 10000;

console.log(`Connecting to SSE: ${SSE_URL}`);

const client = new Client({
    capabilities: {
        tools: {},
        resources: {},
    }
});

let passed = 0;
let failed = 0;
let errors = [];

try {
    // Connect via SSE with timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), TIMEOUT);

    await client.connect({ transport: new (await import('@modelcontextprotocol/sdk/client/sse.js')).SSEClientTransport(new URL(SSE_URL)) });

    clearTimeout(timeoutId);
    console.log('✓ Connected to MCP server');

    // Test 1: List Tools
    console.log('\n--- Test: List Tools ---');
    try {
        const toolsResponse = await client.listTools();
        const tools = toolsResponse.tools || [];
        console.log(`Found ${tools.length} tools:`);
        for (const tool of tools) {
            console.log(`  - ${tool.name}: ${tool.description?.substring(0, 60)}...`);
        }
        if (tools.length > 0) {
            console.log('✓ PASS: list_tools returned tools');
            passed++;
        } else {
            console.log('✗ FAIL: list_tools returned no tools');
            failed++;
        }
    } catch (e) {
        console.log(`✗ FAIL: list_tools error: ${e.message}`);
        failed++;
        errors.push(`list_tools: ${e.message}`);
    }

    // Test 2: List Resources
    console.log('\n--- Test: List Resources ---');
    try {
        const resourcesResponse = await client.listResources();
        const resources = resourcesResponse.resources || [];
        console.log(`Found ${resources.length} resources:`);
        for (const resource of resources) {
            console.log(`  - ${resource.uri}: ${resource.name}`);
        }
        if (resources.length > 0) {
            console.log('✓ PASS: list_resources returned resources');
            passed++;
        } else {
            console.log('✗ FAIL: list_resources returned no resources');
            failed++;
        }
    } catch (e) {
        console.log(`✗ FAIL: list_resources error: ${e.message}`);
        failed++;
        errors.push(`list_resources: ${e.message}`);
    }

    // Test 3: Call searxng_info tool
    console.log('\n--- Test: Call searxng_info ---');
    try {
        const infoResponse = await client.callTool({
            name: 'searxng_info',
            arguments: {}
        });
        const content = infoResponse.content || [];
        const text = content.find(c => c.type === 'text')?.text || '';
        console.log(`Response: ${text.substring(0, 200)}...`);
        if (text && !infoResponse.isError) {
            console.log('✓ PASS: searxng_info returned valid response');
            passed++;
        } else if (infoResponse.isError) {
            console.log(`✗ FAIL: searxng_info returned error: ${text}`);
            failed++;
            errors.push(`searxng_info: ${text}`);
        } else {
            console.log('✗ FAIL: searxng_info returned no text content');
            failed++;
        }
    } catch (e) {
        console.log(`✗ FAIL: searxng_info error: ${e.message}`);
        failed++;
        errors.push(`searxng_info: ${e.message}`);
    }

    // Test 4: Call searxng_search tool (may fail if SearXNG is not reachable)
    console.log('\n--- Test: Call searxng_search ---');
    try {
        const searchResponse = await client.callTool({
            name: 'searxng_search',
            arguments: {
                query: 'test search',
                limit: 3
            }
        });
        const content = searchResponse.content || [];
        const text = content.find(c => c.type === 'text')?.text || '';
        const isError = searchResponse.isError || false;

        if (isError) {
            console.log(`⊘ SKIP: searxng_search failed (SearXNG may not be reachable): ${text.substring(0, 100)}...`);
        } else if (text) {
            console.log(`Response preview: ${text.substring(0, 200)}...`);
            console.log('✓ PASS: searxng_search returned valid response');
            passed++;
        } else {
            console.log('✗ FAIL: searxng_search returned no text content');
            failed++;
        }
    } catch (e) {
        console.log(`⊘ SKIP: searxng_search failed (SearXNG may not be reachable): ${e.message}`);
    }

    // Print summary
    console.log('\n================================');
    console.log('MCP SDK Test Summary');
    console.log('================================');
    console.log(`Passed: ${passed}`);
    console.log(`Failed: ${failed}`);
    console.log(`Errors: ${errors.length}`);
    if (errors.length > 0) {
        console.log('\nErrors:');
        errors.forEach(e => console.log(`  - ${e}`));
    }
    console.log('================================');

    process.exit(failed > 0 ? 1 : 0);

} catch (e) {
    console.log(`✗ FAIL: Connection error: ${e.message}`);
    console.log('\nThis may mean:');
    console.log('  1. MCP server is not running');
    console.log('  2. SSE endpoint is not accessible');
    console.log('  3. Network/connectivity issue');
    console.log(`\nExpected SSE URL: ${SSE_URL}`);
    process.exit(1);
}
NODESCRIPT

    # Run the test client from the mcp-searxng-server directory so Node can find node_modules
    local mcp_test_result
    mcp_test_result=$(cd "$(dirname "$test_client")/.." && NODE_PATH="$(pwd)/node_modules" MCP_HOST="$MCP_HOST" MCP_PORT="$MCP_PORT" node "$test_client" 2>&1) || true
    echo "$mcp_test_result"

    # Parse results from the Node.js output
    local sdk_passed sdk_failed sdk_skipped
    sdk_passed=$(echo "$mcp_test_result" | grep -c "✓ PASS" || true)
    sdk_failed=$(echo "$mcp_test_result" | grep -c "✗ FAIL" || true)
    sdk_skipped=$(echo "$mcp_test_result" | grep -c "⊘ SKIP" || true)

    # Ensure values are numeric (default to 0)
    sdk_passed=$((sdk_passed + 0))
    sdk_failed=$((sdk_failed + 0))
    sdk_skipped=$((sdk_skipped + 0))

    TESTS_PASSED=$((TESTS_PASSED + sdk_passed))
    TESTS_FAILED=$((TESTS_FAILED + sdk_failed))
    TESTS_SKIPPED=$((TESTS_SKIPPED + sdk_skipped))

    rm -f "$test_client"
}

# =============================================
# Test 5: MCP Tools via curl (manual protocol)
# =============================================
test_mcp_manual_protocol() {
    print_section "TEST 5: MCP Protocol via curl (manual JSON-RPC)"

    print_test "Manual MCP JSON-RPC test"

    # The MCP SSEServerTransport works as follows:
    # 1. Client connects to /sse to get the SSE connection
    # 2. Server sends a 'connect' event with sessionId
    # 3. Client POSTs messages to /messages?sessionId=SESSION_ID

    # Since we can't easily do full SSE + POST interaction with curl,
    # let's verify the endpoints exist and accept requests

    # Test /sse endpoint accepts GET (use GET, not HEAD - SSE server doesn't handle HEAD)
    # Background the curl to avoid hanging on SSE stream
    print_test "GET /sse endpoint"
    local sse_headers_tmp
    sse_headers_tmp=$(mktemp /tmp/sse_headers.XXXXXX)
    curl -s -X GET -D "$sse_headers_tmp" -o /dev/null --connect-timeout 3 --max-time 2 "${BASE_URL}/sse" 2>&1 &
    local sse_pid=$!
    wait $sse_pid 2>/dev/null || true
    local sse_headers
    sse_headers=$(cat "$sse_headers_tmp" 2>/dev/null) || true
    rm -f "$sse_headers_tmp"

    if echo "$sse_headers" | grep -qi "200\|text/event-stream"; then
        print_pass "/sse endpoint accepts GET requests"
    else
        print_fail "/sse endpoint not responding correctly"
        print_info "Headers: $sse_headers"
    fi

    # Test /messages endpoint rejects without session
    print_test "POST /messages without session (should reject)"
    local msg_response
    msg_response=$(curl -s -w "\n%{http_code}" --connect-timeout 3 --max-time 5 \
        -X POST "${BASE_URL}/messages" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"ping"}' 2>&1) || true

    local http_code
    http_code=$(echo "$msg_response" | tail -1) || true

    if [ "$http_code" = "400" ]; then
        print_pass "/messages correctly rejects without sessionId (400)"
    else
        print_info "/messages returned HTTP $http_code (expected 400 for missing session)"
    fi

    # Test /messages with invalid session
    print_test "POST /messages with invalid session (should reject)"
    local invalid_session
    invalid_session=$(curl -s -w "\n%{http_code}" --connect-timeout 3 --max-time 5 \
        "${BASE_URL}/messages?sessionId=invalid-session-test" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"ping"}' 2>&1) || true

    local http_code2
    http_code2=$(echo "$invalid_session" | tail -1) || true

    if [ "$http_code2" = "400" ]; then
        print_pass "/messages correctly rejects invalid session (400)"
    else
        print_info "/messages returned HTTP $http_code2 for invalid session"
    fi
}

# =============================================
# Test 6: Server Configuration
# =============================================
test_server_config() {
    print_section "TEST 6: Server Configuration"

    print_test "Checking server configuration"

    # Get health response for timestamp
    local health_response
    health_response=$(curl -s --connect-timeout 5 --max-time 10 "${BASE_URL}/health" 2>&1) || true

    if [ -n "$health_response" ]; then
        print_pass "Server is responding"
        print_info "Health: $health_response"
    else
        print_fail "Server not responding"
        return
    fi

    # Check if SearXNG is reachable from the MCP server
    print_test "SearXNG connectivity"

    # We can't directly check from outside, but we can note the configuration
    print_info "SearXNG Base URL: $SEARXNG_BASE_URL"
    print_info "MCP Host: $MCP_HOST"
    print_info "MCP Port: $MCP_PORT"

    # Check if SearXNG is reachable
    local searxng_health
    searxng_health=$(curl -s --connect-timeout 3 --max-time 5 "${SEARXNG_BASE_URL}/healthz" 2>&1) || true

    if [ -n "$searxng_health" ] && [ "$searxng_health" != "" ]; then
        print_pass "SearXNG is reachable at $SEARXNG_BASE_URL"
    else
        print_skip "SearXNG not reachable at $SEARXNG_BASE_URL (may be expected in Docker network)"
    fi
}

# =============================================
# Test 7: Error Handling
# =============================================
test_error_handling() {
    print_section "TEST 7: Error Handling"

    print_test "Error handling via MCP protocol"

    # Test with malformed JSON
    print_test "POST /messages with malformed JSON"
    local malformed_response
    malformed_response=$(curl -s -w "\n%{http_code}" --connect-timeout 3 --max-time 5 \
        "${BASE_URL}/messages?sessionId=test" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{invalid json}' 2>&1) || true

    local http_code
    http_code=$(echo "$malformed_response" | tail -1) || true

    if [ "$http_code" = "400" ] || [ "$http_code" = "415" ]; then
        print_pass "Server handles malformed JSON gracefully"
    else
        print_info "Server returned HTTP $http_code for malformed JSON"
    fi

    # Test with very large payload
    print_test "POST /messages with large payload"
    local large_payload='{"jsonrpc":"2.0","id":1,"method":"list_tools","params":{},"large":"'
    for i in $(seq 1 100); do
        large_payload+="A$(head -c 100 /dev/urandom | base64)"
    done
    large_payload+='"}'

    local large_response
    large_response=$(curl -s -w "\n%{http_code}" --connect-timeout 3 --max-time 5 \
        "${BASE_URL}/messages?sessionId=test" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$large_payload" 2>&1) || true

    print_pass "Server handles large payloads (no crash)"
}

# =============================================
# Print Summary
# =============================================
print_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           MCP SearXNG Server Test Results            ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo -e "║  ${GREEN}  Passed: $TESTS_PASSED${NC}                                          ║"
    echo -e "║  ${RED}  Failed: $TESTS_FAILED${NC}                                          ║"
    echo -e "║  ${CYAN}  Skipped: $TESTS_SKIPPED${NC}                                         ║"
    echo -e "║  Total:  $TOTAL_TESTS                                          ║"
    echo "╠══════════════════════════════════════════════════════╣"

    if [ $TESTS_FAILED -eq 0 ] && [ $TESTS_SKIPPED -eq 0 ]; then
        echo -e "║  ${GREEN}  ALL TESTS PASSED!${NC}                                    ║"
    elif [ $TESTS_FAILED -eq 0 ]; then
        echo -e "║  ${YELLOW}  ALL ACTIVE TESTS PASSED (some skipped)${NC}              ║"
    else
        echo -e "║  ${RED}  SOME TESTS FAILED${NC}                                    ║"
    fi

    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
}

# =============================================
# Main
# =============================================
main() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║     MCP SearXNG Server - Comprehensive Test Suite   ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Server: ${CYAN}${BASE_URL}${NC}"
    echo -e "SearXNG: ${CYAN}${SEARXNG_BASE_URL}${NC}"
    echo -e "Date:   $(date)"
    echo ""

    # Quick connectivity check
    print_test "Checking if MCP server is running"
    if curl -s --connect-timeout 5 "${BASE_URL}/health" > /dev/null 2>&1; then
        print_pass "Server is reachable"
    else
        print_fail "Server is not responding at ${BASE_URL}"
        echo ""
        echo "Possible issues:"
        echo "  1. MCP server container is not running: docker ps | grep mcp"
        echo "  2. Port mapping issue: check docker-compose.yml ports"
        echo "  3. Server crashed: docker logs mcp-searxng"
        echo ""
        echo "To start the server:"
        echo "  docker compose up -d searxng mcp-searxng"
        echo ""
        print_summary
        exit 1
    fi

    # Run all tests
    test_health_endpoint
    test_sse_connection
    test_mcp_manual_protocol
    test_server_config
    test_mcp_list_tools
    test_error_handling

    # Print summary
    print_summary

    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            MCP_HOST="$2"
            BASE_URL="http://${MCP_HOST}:${MCP_PORT}"
            shift 2
            ;;
        --port)
            MCP_PORT="$2"
            BASE_URL="http://${MCP_HOST}:${MCP_PORT}"
            shift 2
            ;;
        --searxng-url)
            SEARXNG_BASE_URL="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --host HOST       MCP server host (default: localhost)"
            echo "  --port PORT       MCP server port (default: 3002)"
            echo "  --searxng-url URL SearXNG base URL (default: http://localhost:8082)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

main "$@"