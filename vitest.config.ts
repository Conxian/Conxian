import { defineConfig } from 'vitest/config';
import { fileURLToPath } from 'url';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/governance-token.test.ts'],
    exclude: ['stacks/tests/**', 'stacks/sdk-tests/**', 'stacks/tests/helpers/**'],
    testTimeout: 120000,
    hookTimeout: 90000,
    globals: true,
    setupFiles: [
      './stacks/global-vitest.setup.ts',
      './node_modules/@stacks/clarinet-sdk/vitest-helpers/src/vitest.setup.ts',
    ],
    // Enable ESM support
    environmentOptions: {
      environment: 'node',
      transformMode: {
        web: [/.[tj]sx?$/],
      },
    },
  },
});
