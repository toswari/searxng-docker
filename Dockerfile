FROM searxng/searxng:latest

# Install Node.js for MCP server
RUN apk add --no-cache nodejs npm

# Create MCP server directory
RUN mkdir -p /opt/mcp-searxng

# Copy MCP server files
COPY mcp-searxng-server/package.json /opt/mcp-searxng/
COPY mcp-searxng-server/index.js /opt/mcp-searxng/

# Install MCP server dependencies
WORKDIR /opt/mcp-searxng
RUN npm install --production

# Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080 8081

# Use custom entrypoint that starts both SearXNG and MCP server
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]