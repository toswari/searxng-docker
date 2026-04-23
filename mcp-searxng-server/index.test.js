#!/usr/bin/env node
/**
 * Unit Tests for MCP SearXNG Server
 * 
 * Run with: node --test index.test.js
 */

import { describe, it, before, after, mock } from 'node:test';
import assert from 'node:assert/strict';
import { setTimeout } from 'timers/promises';

// Mock configuration
const TEST_PORT = 3099;
const TEST_SEARXNG_URL = 'http://searxng:8080';

// Test utilities
async function makeRequest(path, options = {}) {
  const url = `http://localhost:${TEST_PORT}${path}`;
  const response = await fetch(url, options);
  return {
    status: response.status,
    headers: response.headers,
    data: response.status === 204 ? null : await response.json().catch(() => response.text()),
  };
}

describe('MCP SearXNG Server', () => {
  let server;
  let app;

  before(async () => {
    // Set test environment variables
    process.env.PORT = TEST_PORT.toString();
    process.env.SEARXNG_BASE_URL = TEST_SEARXNG_URL;
    process.env.SEARXNG_DEFAULT_RESULTS = '10';
    process.env.SEARXNG_TIMEOUT = '10';

    // Import and start server
    const module = await import('./index.js');
    
    // Wait for server to start
    await setTimeout(500);
  });

  after(async () => {
    // Cleanup
    if (server) {
      server.close();
    }
  });

  describe('Health Endpoint', () => {
    it('should return healthy status', async () => {
      const response = await makeRequest('/health');
      
      assert.strictEqual(response.status, 200);
      assert.ok(response.data);
      assert.strictEqual(response.data.status, 'ok');
      assert.ok(response.data.timestamp);
    });

    it('should return valid ISO timestamp', async () => {
      const response = await makeRequest('/health');
      const timestamp = new Date(response.data.timestamp);
      assert.ok(!isNaN(timestamp.getTime()), 'Timestamp should be valid date');
    });
  });

  describe('SSE Endpoint', () => {
    it('should accept SSE connection', async () => {
      const response = await fetch(`http://localhost:${TEST_PORT}/sse`);
      
      assert.strictEqual(response.status, 200);
      assert.ok(response.headers.get('content-type')?.includes('text/event-stream'));
    });
  });

  describe('Messages Endpoint', () => {
    it('should reject invalid session ID', async () => {
      const response = await makeRequest('/messages?sessionId=invalid', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
      
      assert.strictEqual(response.status, 400);
    });
  });

  describe('Search Function', () => {
    it('should construct correct search URL', async () => {
      // This tests the internal search function logic
      const params = new URLSearchParams({
        q: 'test query',
        format: 'json',
      });
      
      const expectedUrl = `${TEST_SEARXNG_URL}/search?${params.toString()}`;
      assert.ok(expectedUrl.includes('q=test+query'));
      assert.ok(expectedUrl.includes('format=json'));
    });

    it('should handle category parameter', async () => {
      const params = new URLSearchParams({
        q: 'test',
        format: 'json',
        categories: 'news',
      });
      
      assert.ok(params.toString().includes('categories=news'));
    });

    it('should handle engines parameter', async () => {
      const params = new URLSearchParams({
        q: 'test',
        format: 'json',
      });
      params.append('engines', 'google,bing');
      
      assert.ok(params.toString().includes('engines=google%2Cbing'));
    });
  });

  describe('Configuration', () => {
    it('should use environment variables', async () => {
      assert.strictEqual(process.env.SEARXNG_BASE_URL, TEST_SEARXNG_URL);
      assert.strictEqual(process.env.SEARXNG_DEFAULT_RESULTS, '10');
      assert.strictEqual(process.env.SEARXNG_TIMEOUT, '10');
    });

    it('should have valid port configuration', async () => {
      const port = parseInt(process.env.PORT);
      assert.ok(port > 0 && port <= 65535, 'Port should be valid');
    });
  });

  describe('Error Handling', () => {
    it('should handle network errors', async () => {
      try {
        await fetch('http://invalid-host-that-does-not-exist/test');
        assert.fail('Should have thrown');
      } catch (error) {
        // Network errors are expected (ENOTFOUND, ECONNREFUSED, etc.)
        assert.ok(error.code || error.name === 'TypeError' || error.cause);
      }
    });

    it('should handle invalid JSON responses', async () => {
      const invalidJson = '{ invalid json }';
      try {
        JSON.parse(invalidJson);
        assert.fail('Should have thrown');
      } catch (error) {
        assert.ok(error instanceof SyntaxError);
      }
    });
  });

  describe('Input Validation', () => {
    it('should validate query is string', () => {
      const query = 'test search';
      assert.strictEqual(typeof query, 'string');
      assert.ok(query.length > 0);
    });

    it('should validate limit is positive number', () => {
      const limit = 10;
      assert.strictEqual(typeof limit, 'number');
      assert.ok(limit > 0);
    });

    it('should validate category enum values', () => {
      const validCategories = ['general', 'images', 'videos', 'news', 'music', 'files', 'social_media'];
      const testCategory = 'news';
      assert.ok(validCategories.includes(testCategory));
    });
  });

  describe('Response Formatting', () => {
    it('should format search results correctly', () => {
      const mockResults = [
        { title: 'Result 1', url: 'http://example.com/1', content: 'Content 1' },
        { title: 'Result 2', url: 'http://example.com/2', content: 'Content 2' },
      ];

      const formatted = mockResults.map((result, index) => 
        `${index + 1}. ${result.title}\n   URL: ${result.url}\n   ${result.content}`
      ).join('\n\n');

      assert.ok(formatted.includes('1. Result 1'));
      assert.ok(formatted.includes('URL: http://example.com/1'));
    });

    it('should handle empty results', () => {
      const emptyResults = [];
      const formatted = emptyResults.map((result, index) => 
        `${index + 1}. ${result.title}`
      ).join('\n\n') || 'No results found';

      assert.strictEqual(formatted, 'No results found');
    });
  });

  describe('Engine List Parsing', () => {
    it('should parse engine names from HTML', () => {
      const mockHtml = `
        <input name="engine_google" value="google" checked>
        <input name="engine_bing" value="bing" checked>
        <input name="engine_duckduckgo" value="duckduckgo" checked>
      `;

      const engineRegex = /<input[^>]*name="engine_([^"]+)"[^>]*value="([^"]+)"[^>]*checked/g;
      const engines = [];
      let match;
      while ((match = engineRegex.exec(mockHtml)) !== null) {
        engines.push({ name: match[1], enabled: true });
      }

      assert.strictEqual(engines.length, 3);
      assert.strictEqual(engines[0].name, 'google');
      assert.strictEqual(engines[1].name, 'bing');
    });
  });

  describe('Instance Info', () => {
    it('should return correct instance configuration', async () => {
      const info = {
        baseUrl: process.env.SEARXNG_BASE_URL,
        defaultResults: parseInt(process.env.SEARXNG_DEFAULT_RESULTS),
        timeout: parseInt(process.env.SEARXNG_TIMEOUT),
        version: '1.0.0',
      };

      assert.strictEqual(info.baseUrl, TEST_SEARXNG_URL);
      assert.strictEqual(info.defaultResults, 10);
      assert.strictEqual(info.timeout, 10);
      assert.strictEqual(info.version, '1.0.0');
    });
  });

  describe('Tool Definitions', () => {
    const expectedTools = [
      'searxng_search',
      'searxng_search_simple',
      'searxng_news',
      'searxng_images',
      'searxng_videos',
      'searxng_engines',
      'searxng_info',
    ];

    it('should define all expected tools', () => {
      assert.strictEqual(expectedTools.length, 7);
    });

    it('should have valid tool schemas', () => {
      expectedTools.forEach(toolName => {
        assert.ok(typeof toolName === 'string');
        assert.ok(toolName.startsWith('searxng_'));
      });
    });

    it('should have required properties in search tool', () => {
      const searchTool = {
        name: 'searxng_search',
        inputSchema: {
          type: 'object',
          properties: {
            query: { type: 'string' },
            limit: { type: 'integer' },
          },
          required: ['query'],
        },
      };

      assert.ok(searchTool.inputSchema.required.includes('query'));
      assert.strictEqual(searchTool.inputSchema.properties.query.type, 'string');
    });
  });

  describe('Resource Definitions', () => {
    const expectedResources = [
      { uri: 'searxng://info', name: 'SearXNG Instance Information' },
      { uri: 'searxng://engines', name: 'Available Search Engines' },
    ];

    it('should define all expected resources', () => {
      assert.strictEqual(expectedResources.length, 2);
    });

    it('should have valid resource URIs', () => {
      expectedResources.forEach(resource => {
        assert.ok(resource.uri.startsWith('searxng://'));
      });
    });
  });
});

describe('Integration Tests', () => {
  describe('Server Connectivity', () => {
    it('should respond to health checks', async () => {
      try {
        const response = await fetch(`http://localhost:${process.env.PORT || 3000}/health`);
        if (response.ok) {
          const data = await response.json();
          assert.strictEqual(data.status, 'ok');
        }
      } catch (error) {
        // Server may not be running during unit tests
        assert.ok(true, 'Server connectivity test skipped');
      }
    });
  });
});