#!/usr/bin/env node
/**
 * MCP Server for SearXNG Metasearch Engine
 * 
 * This server provides tools and resources for searching the web using SearXNG,
 * a privacy-respecting metasearch engine.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

// Configuration
const SEARXNG_BASE_URL = process.env.SEARXNG_BASE_URL || 'http://localhost:8082';
const DEFAULT_RESULTS = parseInt(process.env.SEARXNG_DEFAULT_RESULTS) || 10;
const DEFAULT_TIMEOUT = parseInt(process.env.SEARXNG_TIMEOUT) || 10;

/**
 * Perform a search request to SearXNG
 * @param {string} query - Search query
 * @param {string} format - Response format (json, html, csv, rss)
 * @param {number} limit - Maximum number of results
 * @param {string} category - Search category (general, images, videos, news, etc.)
 * @param {string[]} engines - Specific engines to use
 * @returns {Promise<object>} Search results
 */
async function search(query, format = 'json', limit = DEFAULT_RESULTS, category = null, engines = null) {
  const params = new URLSearchParams({
    q: query,
    format: format,
  });

  if (category) {
    params.append('categories', category);
  }

  if (engines && engines.length > 0) {
    params.append('engines', engines.join(','));
  }

  const url = `${SEARXNG_BASE_URL}/search?${params.toString()}`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT * 1000);

  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'Accept': 'application/json',
      },
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`SearXNG request failed: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    
    // Limit results if specified
    if (data.results && limit > 0) {
      data.results = data.results.slice(0, limit);
    }

    return data;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error.name === 'AbortError') {
      throw new Error(`Search timeout after ${DEFAULT_TIMEOUT} seconds`);
    }
    throw error;
  }
}

/**
 * Get available engines from SearXNG
 * @returns {Promise<object>} List of available engines
 */
async function getEngines() {
  const url = `${SEARXNG_BASE_URL}/preferences`;
  
  try {
    const response = await fetch(url, {
      headers: {
        'Accept': 'text/html',
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch engines: ${response.status}`);
    }

    // Parse the HTML to extract engine list
    const html = await response.text();
    const engines = [];
    
    // Extract engine checkboxes from the HTML
    const engineRegex = /<input[^>]*name="engine_([^"]+)"[^>]*value="([^"]+)"[^>]*checked/g;
    let match;
    while ((match = engineRegex.exec(html)) !== null) {
      engines.push({
        name: match[1],
        enabled: true,
      });
    }

    return { engines };
  } catch (error) {
    // Return default engine list if preferences page fails
    return {
      engines: [
        { name: 'google', enabled: true },
        { name: 'bing', enabled: true },
        { name: 'duckduckgo', enabled: true },
        { name: 'brave', enabled: true },
        { name: 'wikipedia', enabled: true },
        { name: 'github', enabled: true },
        { name: 'arxiv', enabled: true },
      ],
    };
  }
}

/**
 * Get SearXNG instance info
 * @returns {Promise<object>} Instance information
 */
async function getInstanceInfo() {
  return {
    baseUrl: SEARXNG_BASE_URL,
    defaultResults: DEFAULT_RESULTS,
    timeout: DEFAULT_TIMEOUT,
    version: '1.0.0',
  };
}

// Create MCP Server
const server = new Server(
  {
    name: 'mcp-searxng-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
      resources: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'searxng_search',
        description: 'Search the web using SearXNG metasearch engine. Returns structured search results with titles, URLs, and content snippets.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'The search query',
            },
            limit: {
              type: 'integer',
              description: 'Maximum number of results to return (default: 10)',
              default: 10,
            },
            category: {
              type: 'string',
              description: 'Search category: general, images, videos, news, music, files, social_media',
              enum: ['general', 'images', 'videos', 'news', 'music', 'files', 'social_media'],
            },
            engines: {
              type: 'array',
              items: { type: 'string' },
              description: 'Specific engines to use (e.g., ["google", "bing"])',
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'searxng_search_simple',
        description: 'Simple search that returns formatted results as text. Best for quick lookups.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'The search query',
            },
            limit: {
              type: 'integer',
              description: 'Maximum number of results (default: 5)',
              default: 5,
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'searxng_news',
        description: 'Search specifically for news articles using SearXNG.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'The news search query',
            },
            limit: {
              type: 'integer',
              description: 'Maximum number of results (default: 10)',
              default: 10,
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'searxng_images',
        description: 'Search for images using SearXNG.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'The image search query',
            },
            limit: {
              type: 'integer',
              description: 'Maximum number of results (default: 10)',
              default: 10,
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'searxng_videos',
        description: 'Search for videos using SearXNG.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'The video search query',
            },
            limit: {
              type: 'integer',
              description: 'Maximum number of results (default: 10)',
              default: 10,
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'searxng_engines',
        description: 'Get the list of available search engines configured in SearXNG.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'searxng_info',
        description: 'Get information about the SearXNG instance configuration.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'searxng_search': {
        const { query, limit = 10, category, engines } = args;
        const results = await search(query, 'json', limit, category, engines);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(results, null, 2),
            },
          ],
        };
      }

      case 'searxng_search_simple': {
        const { query, limit = 5 } = args;
        const results = await search(query, 'json', limit);
        
        const formattedResults = results.results?.map((result, index) => 
          `${index + 1}. ${result.title}\n   URL: ${result.url}\n   ${result.content || 'No description available'}`
        ).join('\n\n') || 'No results found';

        return {
          content: [
            {
              type: 'text',
              text: `Search results for: "${query}"\n\n${formattedResults}`,
            },
          ],
        };
      }

      case 'searxng_news': {
        const { query, limit = 10 } = args;
        const results = await search(query, 'json', limit, 'news');
        
        const formattedResults = results.results?.map((result, index) => 
          `${index + 1}. ${result.title}\n   URL: ${result.url}\n   ${result.content || 'No description available'}${result.publishedDate ? `\n   Date: ${result.publishedDate}` : ''}`
        ).join('\n\n') || 'No results found';

        return {
          content: [
            {
              type: 'text',
              text: `News results for: "${query}"\n\n${formattedResults}`,
            },
          ],
        };
      }

      case 'searxng_images': {
        const { query, limit = 10 } = args;
        const results = await search(query, 'json', limit, 'images');
        
        const formattedResults = results.results?.map((result, index) => 
          `${index + 1}. ${result.title}\n   URL: ${result.url}\n   Thumbnail: ${result.thumbnail || 'N/A'}\n   Source: ${result.source || 'Unknown'}`
        ).join('\n\n') || 'No results found';

        return {
          content: [
            {
              type: 'text',
              text: `Image results for: "${query}"\n\n${formattedResults}`,
            },
          ],
        };
      }

      case 'searxng_videos': {
        const { query, limit = 10 } = args;
        const results = await search(query, 'json', limit, 'videos');
        
        const formattedResults = results.results?.map((result, index) => 
          `${index + 1}. ${result.title}\n   URL: ${result.url}\n   ${result.content || 'No description available'}`
        ).join('\n\n') || 'No results found';

        return {
          content: [
            {
              type: 'text',
              text: `Video results for: "${query}"\n\n${formattedResults}`,
            },
          ],
        };
      }

      case 'searxng_engines': {
        const engines = await getEngines();
        return {
          content: [
            {
              type: 'text',
              text: `Available search engines:\n\n${engines.engines.map(e => `- ${e.name}${e.enabled ? ' (enabled)' : ''}`).join('\n')}`,
            },
          ],
        };
      }

      case 'searxng_info': {
        const info = await getInstanceInfo();
        return {
          content: [
            {
              type: 'text',
              text: `SearXNG Instance Info:\n\nBase URL: ${info.baseUrl}\nDefault Results: ${info.defaultResults}\nTimeout: ${info.timeout}s\nMCP Server Version: ${info.version}`,
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});

// List available resources
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return {
    resources: [
      {
        uri: 'searxng://info',
        name: 'SearXNG Instance Information',
        description: 'Information about the SearXNG instance configuration',
        mimeType: 'application/json',
      },
      {
        uri: 'searxng://engines',
        name: 'Available Search Engines',
        description: 'List of search engines configured in SearXNG',
        mimeType: 'application/json',
      },
    ],
  };
});

// Handle resource reads
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;

  switch (uri) {
    case 'searxng://info': {
      const info = await getInstanceInfo();
      return {
        contents: [
          {
            uri,
            mimeType: 'application/json',
            text: JSON.stringify(info, null, 2),
          },
        ],
      };
    }

    case 'searxng://engines': {
      const engines = await getEngines();
      return {
        contents: [
          {
            uri,
            mimeType: 'application/json',
            text: JSON.stringify(engines, null, 2),
          },
        ],
      };
    }

    default:
      throw new Error(`Unknown resource: ${uri}`);
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('MCP SearXNG Server running on stdio');
  console.error(`SearXNG Base URL: ${SEARXNG_BASE_URL}`);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});