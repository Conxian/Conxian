import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['stacks/tests/**/*.test.ts'],
    environment: 'node',
    setupFiles: ['./tests/vitest.setup.ts'],
    testTimeout: 60000,
    hookTimeout: 60000,
  },
});
