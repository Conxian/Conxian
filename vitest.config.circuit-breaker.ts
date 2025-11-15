import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/circuit-breaker/**/*.test.ts'],
    testTimeout: 60000,
    hookTimeout: 30000,
    setupFiles: ['./tests/setup.ts'],
    coverage: {
      reporter: ['text', 'json', 'html'],
      include: ['contracts/security/*.clar'],
      exclude: ['**/node_modules/**', '**/tests/**']
    }
  },
});
