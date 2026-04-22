# SearXNG Docker

A Docker-based deployment of [SearXNG](https://github.com/searxng/searxng), a privacy-respecting, hackable metasearch engine.

## Overview

This setup runs SearXNG in a Docker container with pre-configured search engines and JSON output support.

## Ports

| Container Port | Host Port | Description |
|----------------|-----------|-------------|
| 8080           | 8082      | Web interface and API |

**Access the web interface at:** `http://localhost:8082`

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

## OpenClaw Skill

This repository includes an [OpenClaw skill](https://github.com/modelcontextprotocol/servers) for searching the web via SearXNG.

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

- Google
- Bing
- DuckDuckGo
- Brave
- Wikipedia
- GitHub
- StackOverflow
- arXiv

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

## License

SearXNG is licensed under the GNU Affero General Public License v3.0.