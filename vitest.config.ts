import { defineConfig } from 'vitest/config';
import { fileURLToPath } from 'url';

export default defineConfig({
  test: {
    environment: 'vitest-environment-clarinet/devnet',
    include: ['tests/**/*.test.ts'],
    exclude: ['stacks/tests/**', 'stacks/sdk-tests/**', 'stacks/tests/helpers/**'],
    testTimeout: 120000,
    hookTimeout: 90000,
    globals: true,
    setupFiles: [
      './stacks/global-vitest.setup.ts',
      'vitest-environment-clarinet/setup',
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
