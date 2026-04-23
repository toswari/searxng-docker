FROM searxng/searxng:latest

# searXNG supports JSON output via the /search?format=json endpoint
# No additional packages needed - use built-in tools

EXPOSE 8080

CMD ["/sbin/tini", "--", "python", "-m", "searxng"]
