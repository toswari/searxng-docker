# Lessons Learned: MCP Server and SearXNG Integration

## Overview

This document captures lessons learned from setting up a working MCP (Model Context Protocol) server integrated with SearXNG for AI agent use. The goal was to create a reliable search backend that AI agents can query programmatically.

---

## 1. SearXNG Configuration

### Engine Selection is Critical

**Problem:** Many default SearXNG engines fail to load or work reliably:
- `stackoverflow` - Missing engine file in the Docker image
- `ahmia`, `torch` - Engine files don't exist
- `wikidata` - API response format changes cause init failures
- `karmasearch` - Returns 403 errors (access denied)
- `brave` - Rate limits aggressively (429 errors)
- `yahoo news` - Frequent server disconnections

**Solution:** Explicitly configure only working engines in `settings.yml`:

```yaml
use_default_settings: true

engines:
  # Working engines with rate limiting
  - name: google
    engine: google
    shortcut: go
    time_between_searches: 2.0

  - name: bing
    engine: bing
    shortcut: bi
    time_between_searches: 2.0

  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg
    time_between_searches: 2.0

  - name: brave
    engine: brave
    shortcut: brave
    time_between_searches: 5.0

  # Disable problematic engines
  - name: ahmia
    disabled: true
  - name: stackoverflow
    disabled: true
  - name: torch
    disabled: true
  - name: wikidata
    disabled: true
  - name: karmasearch
    disabled: true
```

### Rate Limiting Configuration

**Problem:** Search engines rate limit aggressive querying, causing 429 errors and temporary suspensions.

**Solution:** Add `time_between_searches` to each engine configuration:
- General search engines: 2.0 seconds
- Aggressive rate-limited engines (Brave): 5.0 seconds

### JSON Output Format

**Problem:** AI agents need structured data, not HTML.

**Solution:** Enable JSON format in search settings:

```yaml
search:
  formats:
    - html
    - json
    - csv
    - rss
```

Query with `?format=json` parameter for structured results.

---

## 2. Docker Entrypoint Configuration

### Use Granian ASGI Server

**Problem:** Custom entrypoint scripts may not match the official SearXNG image expectations.

**Solution:** Use granian directly in `docker-entrypoint.sh`:

```bash
#!/bin/bash
echo "Starting SearXNG with granian..."
exec granian --interface asgi --host 0.0.0.0 --port 8080 searx.webapp:app
```

This matches the official SearXNG Docker image and ensures proper ASGI application loading.

---

## 3. MCP Server Development

### MCP Server Structure

**Key Components:**
1. `index.js` - Main MCP server with tool definitions
2. `package.json` - Dependencies (@modelcontextprotocol/sdk)
3. `install-mcp-server.sh` - Installation script

### Tool Definition Best Practices

**Example MCP Tool:**

```javascript
const server = new Server(
  { name: 'searxng-server', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name === 'search') {
    const { query, category } = request.params.arguments;
    const response = await fetch(`http://localhost:8082/search?q=${encodeURIComponent(query)}&format=json`);
    const results = await response.json();
    return {
      content: [{ type: 'text', text: JSON.stringify(results, null, 2) }]
    };
  }
});
```

### Error Handling in MCP Tools

**Important:** Always handle:
- Network timeouts
- Empty results
- Rate limiting responses
- Invalid JSON responses

---

## 4. Docker Compose Configuration

### Port Mapping

```yaml
services:
  searxng:
    ports:
      - "8082:8080"  # Host:Container
```

**Note:** Container always uses internal port 8080; host port can be customized.

### Health Checks

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
  interval: 30s
  timeout: 10s
  retries: 3
```

---

## 5. Common Errors and Solutions

### Engine Loading Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `FileNotFoundError: stackoverflow.py` | Engine file missing in image | Disable engine in config |
| `KeyError: 'name'` in wikidata | API response format changed | Disable engine or patch code |
| `loading engine X failed: set engine to inactive` | Various engine issues | SearXNG handles gracefully; can ignore or disable |

### Runtime Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `HTTP 429 Too Many Requests` | Rate limiting | Increase `time_between_searches` |
| `HTTP 403 Forbidden` | Access denied (karmasearch) | Disable engine |
| `Server disconnected` | Server timeout (yahoo) | Disable engine or increase timeout |

### Configuration Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `ValueError: Invalid settings.yml` | Missing required settings | Use `use_default_settings: true` |
| `The "engine" field is missing` | Incomplete engine config | Either specify `engine:` or use `disabled: true` |

---

## 6. AI Agent Integration

### Query Format for Agents

AI agents should query SearXNG using:

```
GET http://localhost:8082/search?q={query}&format=json&categories={category}
```

**Categories:** general, images, videos, news, map, music, files, social media

### Response Parsing

```javascript
{
  "query": "search term",
  "number_of_results": 10,
  "results": [
    {
      "url": "https://example.com",
      "title": "Page Title",
      "content": "Snippet text...",
      "engine": "google",
      "category": "general"
    }
  ],
  "suggestions": ["related search 1", "related search 2"]
}
```

### Best Practices for Agents

1. **Add delays between searches** - Respect rate limits
2. **Use specific categories** - Faster results with `&categories=general`
3. **Handle empty results** - Check `number_of_results` before parsing
4. **Rotate engines** - If one engine fails, try another
5. **Cache results** - Avoid duplicate queries

---

## 7. Installation Checklist

### For New Deployments

- [ ] Clone repository with submodules
- [ ] Review and customize `searxng/settings.yml`
- [ ] Set unique `secret_key` in settings
- [ ] Configure working engines only
- [ ] Set appropriate rate limits
- [ ] Run `docker compose up -d`
- [ ] Verify with `docker compose logs -f`
- [ ] Test search: `curl "http://localhost:8082/search?q=test&format=json"`
- [ ] Install MCP server: `./install-mcp-server.sh`
- [ ] Add MCP server to IDE configuration

---

## 8. Troubleshooting Commands

```bash
# Check container status
docker compose ps

# View logs
docker compose logs -f searxng

# Restart service
docker compose restart

# Rebuild from scratch
docker compose down && docker compose up -d --build

# Test search endpoint
curl "http://localhost:8082/search?q=test&format=json"

# Check available engines
curl "http://localhost:8082/config" | jq '.engines'
```

---

## 9. File Structure Reference

```
searxng-docker/
├── docker-compose.yml          # Docker orchestration
├── Dockerfile                  # Custom image (if needed)
├── docker-entrypoint.sh        # Container startup script
├── searxng/
│   └── settings.yml           # SearXNG configuration
├── mcp-searxng-server/
│   ├── index.js               # MCP server implementation
│   ├── package.json           # Node.js dependencies
│   └── install-mcp-server.sh  # Installation script
└── openclaw-skill/
    ├── SKILL.md               # Skill documentation
    └── scripts/
        ├── searxng-search.sh
        └── searxng-search-save.sh
```

---

## 10. Key Takeaways

1. **Less is More:** Fewer working engines beat many broken ones
2. **Rate Limiting is Essential:** Prevents 429 errors and IP bans
3. **JSON Output:** Critical for programmatic/AI consumption
4. **Graceful Degradation:** SearXNG handles engine failures well
5. **Health Checks:** Ensure container is ready before use
6. **Documentation:** Clear error messages help future debugging

---

## Contributing

When adding new engines or configurations:
1. Test thoroughly with various queries
2. Monitor logs for errors
3. Update this document with findings
4. Verify MCP tool compatibility

---

*Last updated: 2026-04-23*
*SearXNG Version: 2026.4.22-74f1ca203*