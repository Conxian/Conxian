import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    testTimeout: 1800000, // 30 minutes for massive scale tests
    hookTimeout: 300000,   // 5 minutes for setup/teardown
    pool: 'forks',
    maxConcurrency: 1,     // Run load tests sequentially
    reporters: ['verbose', 'json'],
    outputFile: {
      json: './load-test-results.json'
    }
  }
});
