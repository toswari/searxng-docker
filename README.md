
A Docker-based deployment of [SearXNG](https://github.com/searxng/searxng), a privacy-respecting, hackable metasearch engine.

## Overview

This setup runs SearXNG in a Docker container with pre-configured search engines and JSON output support.

## Ports

| Container Port | Host Port | Description |
|----------------|-----------|-------------|
| 8080           | 8082      | SearXNG web interface and API |
| 3000           | 3002      | MCP server for AI agents |

**Access the web interface at:** `http://localhost:8082`

**MCP server endpoint:** `http://localhost:3002/sse`

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

### Using Docker CLI

```bash
# Build the image
docker build -t searxng-local .

# Run the container
docker run -d \
  --name searxng \
  -p 8082:8080 \
  -v $(pwd)/searxng:/etc/searxng \
  -e SEARXNG_BASE_URL=http://localhost:8082/ \
  searxng-local
```

## API Usage

SearXNG supports multiple output formats including JSON, CSV, and RSS.

### Search Endpoint

```
GET /search?q=<query>&format=<format>
```

### Examples

#### JSON Output

```bash
curl "http://localhost:8082/search?q=docker+tutorial&format=json"
```

#### CSV Output

```bash
curl "http://localhost:8082/search?q=docker+tutorial&format=csv"
```

#### RSS Feed

```bash
curl "http://localhost:8082/search?q=docker+tutorial&format=rss"
```

### Using the Helper Scripts

This repository includes helper scripts for querying the API:

```bash
# Query and get JSON output
./query-json.sh "your search query"

# Python script for more complex queries
python query_searxng.py "your search query"
```

## MCP Server for AI Agents

This repository includes an MCP (Model Context Protocol) server that allows AI agents to search the web using SearXNG.

### Option 1: Docker-based MCP Server (Recommended)

The MCP server runs as a separate container alongside SearXNG. When you run docker-compose, both services start automatically.

```bash
# Build and start both services
docker-compose up -d --build
```

The MCP server is accessible via HTTP/SSE transport at `http://localhost:3002/sse`.

### Option 2: Standalone Installation (for Claude Desktop)

For use with Claude Desktop, install the MCP server locally:

```bash
./mcp-searxng-server/install-mcp-server.sh
```

This will:
1. Install Node.js dependencies
2. Configure Claude Desktop to use the MCP server

### MCP Server Structure

```
mcp-searxng-server/
├── package.json                    # Node.js dependencies
├── index.js                        # MCP server implementation
└── install-mcp-server.sh           # Installation script
```

### Available Tools

| Tool | Description |
|------|-------------|
| `searxng_search` | Full search with category and engine options |
| `searxng_search_simple` | Quick formatted search results |
| `searxng_news` | Search news articles |
| `searxng_images` | Search images |
| `searxng_videos` | Search videos |
| `searxng_engines` | List available search engines |
| `searxng_info` | Get SearXNG instance info |

### Example Tool Usage

```json
// Search for news
{
  "name": "searxng_news",
  "arguments": {
    "query": "AI developments 2026",
    "limit": 5
  }
}

// Search with specific engines
{
  "name": "searxng_search",
  "arguments": {
    "query": "docker tutorial",
    "limit": 10,
    "engines": ["google", "bing"]
  }
}

// Search images
{
  "name": "searxng_images",
  "arguments": {
    "query": "sunset beach",
    "limit": 10
  }
}
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SEARXNG_BASE_URL` | SearXNG server URL (internal) | `http://searxng:8080` |
| `SEARXNG_DEFAULT_RESULTS` | Default result count | `10` |
| `SEARXNG_TIMEOUT` | Request timeout (seconds) | `10` |

### Connecting to the MCP Server

For external MCP clients, connect to:

```
http://localhost:3002/sse
```

For Claude Desktop integration, add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "searxng": {
      "url": "http://localhost:3002/sse"
    }
  }
}
```

### Manual Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "searxng": {
      "command": "node",
      "args": ["/path/to/mcp-searxng-server/index.js"],
      "env": {
        "SEARXNG_BASE_URL": "http://localhost:8082"
      }
    }
  }
}
```

## OpenClaw Skill

This repository also includes an [OpenClaw skill](https://github.com/modelcontextprotocol/servers) for searching the web via SearXNG.

### Installing the Skill

```bash
./install-openclaw-skill.sh
```

This will install the `searxng-search` skill to `~/.openclaw/skills/searxng-search/`.

### Skill Structure

```
openclaw-skill/
├── SKILL.md                          # Skill definition and documentation
└── scripts/
    ├── searxng-search.sh             # Search and output to stdout
    └── searxng-search-save.sh        # Search and save results to file
```

### Using the Skill Scripts

```bash
# Search and output to stdout
~/.openclaw/skills/searxng-search/scripts/searxng-search.sh "docker compose"

# Search with custom result count
~/.openclaw/skills/searxng-search/scripts/searxng-search.sh "AI news" 20

# Search and save to file
~/.openclaw/skills/searxng-search/scripts/searxng-search-save.sh "OpenAI" results.json

# Format output with clickable URLs
~/.openclaw/skills/searxng-search/scripts/searxng-search.sh "query" | \
  jq -r '.results[:10] | .[] | "\(.title)\n<\(.url)>\n\(.content | split("\n")[0])\n---"'
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SEARXNG_BASE_URL` | Base URL for the instance | `http://localhost:8082/` |
| `SEARXNG_HOSTNAME` | Hostname for the instance | `localhost` |

### Customizing Settings

Edit `searxng/settings.yml` to customize:

- Search engines (enabled/disabled)
- Safe search level
- UI theme
- Server settings

After making changes, restart the container:

```bash
docker-compose restart
```

### Enabled Search Engines

The following engines are enabled by default:

| Engine | Shortcut | Rate Limit Protection |
|--------|----------|----------------------|
| Google | `go` | 2s delay between searches |
| Bing | `bi` | 2s delay between searches |
| DuckDuckGo | `ddg` | 2s delay between searches |
| Brave | `brave` | 5s delay between searches |
| Wikipedia | `wp` | - |
| GitHub | `gh` | - |
| arXiv | `arx` | - |

### Disabled Engines

The following engines are disabled due to various issues:

| Engine | Reason |
|--------|--------|
| StackOverflow | `stackoverflow.py` not found in SearXNG installation |
| ahmia | Engine loading failed |
| torch | Engine loading failed |
| wikidata | Init method fails with KeyError: 'name' |
| KarmaSearch | HTTP 403 Forbidden (requires API key or has IP restrictions) |
| Yahoo News | Server frequently disconnects |
| Brave News/Images/Videos | Rate limiting (429 errors) |

> **Note:** You may see ERROR logs for disabled engines (ahmia, torch, wikidata) during startup. These are expected and confirm the engines are being properly disabled rather than causing silent failures.

## Security

The container runs with dropped capabilities for enhanced security:

```yaml
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETGID
  - SETUID
```

## Health Check

A health check is configured to verify the service is running:

```bash
docker inspect --format='{{.State.Health.Status}}' searxng
```

## Troubleshooting

### Container won't start

Check the logs:
```bash
docker-compose logs
```

### Docker Desktop doesn't show port mapping

If Docker Desktop shows the container but doesn't display the port mapping in the UI:

1. **Verify the container is running correctly:**
   ```bash
   docker ps --filter "name=searxng"
   ```
   You should see: `0.0.0.0:8082->8080/tcp`

2. **Test the connection:**
   ```bash
   curl http://localhost:8082/
   ```

3. **Refresh Docker Desktop:**
   - Click the refresh button or press `Cmd+R`
   - Or quit and reopen Docker Desktop

This is a known Docker Desktop UI caching issue - the container works correctly even if the ports aren't displayed.

### Port already in use

If port 8082 is already in use, modify the port mapping in `docker-compose.yml`:
```yaml
ports:
  - "8083:8080"  # Change 8082 to another available port
```

### Reset configuration

To reset to default settings:
```bash
rm -rf searxng/
docker-compose down
docker-compose up -d
```

## Lessons Learned

A comprehensive lessons learned document is available in [LESSONS_LEARNED.md](LESSONS_LEARNED.md) covering:

- **Engine Selection:** Which engines work reliably and which to avoid
- **Rate Limiting:** Configuration to prevent 429 errors and IP bans
- **Docker Entrypoint:** Using granian ASGI server correctly
- **MCP Server Development:** Tool patterns and error handling
- **Common Errors:** Complete troubleshooting tables with solutions
- **AI Agent Integration:** Query formats and best practices
- **Installation Checklist:** Step-by-step deployment guide

## License

SearXNG is licensed under the GNU Affero General Public License v3.0.
