#!/usr/bin/env python3
"""
Query searXNG and output JSON results to a file.
Usage: python query_searxng.py <query> [output_file]
"""

import json
import sys
import os

# Use searXNG's internal Python API
sys.path.insert(0, '/usr/local/searxng')

try:
    from searx.search import Search
    from searx.engines import load_engines
    from searx import settings
    
    def search_json(query: str, output_file: str = 'results.json'):
        """Query searXNG and save results as JSON"""
        
        # Load search settings
        load_engines(settings.engines)
        
        # Create search object
        search = Search()
        search.search(query, lang='en')
        
        # Extract results
        results = []
        for result in search.results:
            results.append({
                'title': result.get('title', ''),
                'url': result.get('url', ''),
                'content': result.get('content', ''),
                'engine': result.get('engine', '')
            })
        
        # Save to JSON file
        output = {
            'query': query,
            'result_count': len(results),
            'results': results
        }
        
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)
        
        print(f"Saved {len(results)} results to {output_file}")
        return output_file

    if __name__ == '__main__':
        query = sys.argv[1] if len(sys.argv) > 1 else 'docker'
        output = sys.argv[2] if len(sys.argv) > 2 else 'results.json'
        search_json(query, output)
        
except ImportError as e:
    print(f"Error: {e}")
    print("This script must run inside a searXNG container with proper environment")
    sys.exit(1)
