---
name: searxng-search
description: "Search the web using a local SearXNG instance running on port 8082. Returns JSON results for web queries."
---

# SearXNG Search Skill for OpenClaw

Search the web using your local SearXNG container with MCP server integration.

## OpenClaw Configuration

To use this skill with OpenClaw, add the following to your OpenClaw configuration:

```yaml
# ~/.openclaw/config.yaml or your project's openclaw.yaml
skills:
  - name: searxng-search
    path: ~/.openclaw/skills/searxng-search
    enabled: true
    config:
      searxng_url: http://localhost:8082
      default_results: 10
      timeout: 10
```

## MCP Server Integration

This skill works alongside the MCP server for enhanced functionality:

### Option 1: Using OpenClaw Skill (this skill)

```bash
# Install the skill
./install-openclaw-skill.sh

# Use in OpenClaw workflows
openclaw run searxng-search --query "your search query"
```

### Option 2: Using MCP Server directly

The MCP server provides additional tools that can be used with OpenClaw:

```yaml
# ~/.openclaw/config.yaml
mcp:
  servers:
    searxng:
      command: node
      args:
        - /path/to/mcp-searxng-server/index.js
      env:
        SEARXNG_BASE_URL: http://localhost:8082
```

### Using Both Together

For best results, use both the skill and MCP server:

1. **Skill** - For simple web searches triggered by OpenClaw workflows
2. **MCP Server** - For AI agent interactions via Claude Desktop or other MCP clients

Search the web using your local SearXNG container.

## Prerequisites

- SearXNG container running on http://localhost:8082
- Docker container: `searxng` (started via `~/searxng-docker/docker-compose.yml`)
- `jq` installed for JSON processing
- OpenClaw installed and configured

## Installation

### Step 1: Start SearXNG Container

```bash
cd ~/searxng-docker
docker compose up -d
```

### Step 2: Install the OpenClaw Skill

```bash
./install-openclaw-skill.sh
```

This will:
1. Create the skill directory at `~/.openclaw/skills/searxng-search/`
2. Copy SKILL.md and scripts
3. Make scripts executable

### Step 3: Verify Installation

```bash
# Check skill is installed
ls ~/.openclaw/skills/searxng-search/

# Test the script
~/.openclaw/skills/searxng-search/scripts/searxng-search.sh "test query"
```

### Step 4: Configure OpenClaw (Optional)

Add to your `~/.openclaw/config.yaml`:

```yaml
skills:
  searxng-search:
    default_results: 10
    timeout: 10
    searxng_url: http://localhost:8082
```

## Scripts

Two helper scripts are available in `scripts/`:

### 1. searxng-search.sh - Output to stdout

Returns JSON results directly to stdout (pipe-friendly).

```bash
# Basic usage
~/.openclaw/skills/searxng-search/scripts/searxng-search.sh "docker compose"

# With result count
~/.openclaw/skills/searxng-search/scripts/searxng-search.sh "AI news" 20

# Pipe to jq for formatted output with clickable URLs
~/.openclaw/skills/searxng-search/scripts/searxng-search.sh "OpenAI" | jq -r '.results[:10] | .[] | "\(.title)\n<\(.url)>\n\(.content | split("\n")[0])\n---"'
```

### 2. searxng-search-save.sh - Save to file

Saves results to a file with summary output (based on your original script).

```bash
# Basic usage (saves to results.json)
~/.openclaw/skills/searxng-search/scripts/searxng-search-save.sh "docker compose"

# Custom output file
~/.openclaw/skills/searxng-search/scripts/searxng-search-save.sh "AI news" my-results.json

# With custom count
~/.openclaw/skills/searxng-search/scripts/searxng-search-save.sh "OpenAI" results.json 20
```

## Formatted Output Example

To get clickable URLs in Discord/webchat, use this jq filter:

```bash
~/.openclaw/skills/searxng-search/scripts/searxng-search.sh "query" | jq -r '.results[:10] | .[] | "\(.title)\n<\(.url)>\n\(.content | split("\n")[0])\n---"'
```

This outputs:
```
Article Title
<https://example.com>
Snippet text...
---
```

## Direct curl Usage

When this skill is triggered, use the `exec` tool to query SearXNG:

```bash
curl -s "http://localhost:8082/search?q=YOUR_QUERY&format=json&count=10"
```

### Parameters

- `q` - Search query (URL-encoded)
- `format=json` - Required for JSON output
- `count` - Number of results (1-50, default: 10)
- `engines` - Comma-separated list of engines (optional): google,bing,duckduckgo,brave,wikipedia
- `categories` - Search categories (optional): general,news,science,it

### Example Queries

```bash
# Basic search
curl -s "http://localhost:8082/search?q=artificial+intelligence+news&format=json&count=10"

# News category
curl -s "http://localhost:8082/search?q=AI+breakthrough&categories=news&format=json"

# Specific engines
curl -s "http://localhost:8082/search?q=OpenAI&engines=google,bing&format=json"

# With headers (bypass rate limiting)
curl -s "http://localhost:8082/search?q=docker&format=json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -H "User-Agent: Mozilla/5.0" \
  -H "Accept: application/json"
```

### Response Format

The API returns JSON with this structure:
```json
{
  "query": "search term",
  "number_of_results": 1234,
  "results": [
    {
      "title": "Result Title",
      "url": "https://example.com",
      "content": "Snippet text...",
      "publishedDate": "2026-03-17T...",
      "engine": "brave",
      "score": 1.5
    }
  ],
  "suggestions": [...],
  "unresponsive_engines": [...]
}
```

## Troubleshooting

If SearXNG is not responding:
1. Check container status: `docker ps | grep searxng`
2. Restart if needed: `cd ~/searxng-docker && docker compose restart`
3. Check logs: `docker logs searxng`

## Notes

- Results are aggregated from multiple search engines (Brave, Bing, Startpage, etc.)
- Some engines may be unresponsive due to CAPTCHA or rate limiting
- The container runs locally - no API keys required
- Scripts include headers to help bypass rate limiting
- Wrap URLs in `<>` for clickable links in Discord/webchat