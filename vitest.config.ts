import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    exclude: ['stacks/tests/**', 'stacks/sdk-tests/**', 'stacks/tests/helpers/**'],
    testTimeout: 120000,
    hookTimeout: 90000,
    globals: true,
    setupFiles: [
      './stacks/global-vitest.setup.ts',
      './node_modules/@hirosystems/clarinet-sdk/vitest-helpers/src/vitest.setup.ts',
    ],
  },
});
