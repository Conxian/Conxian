import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "clarinet",
    environmentOptions: {
      clarinet: {
        manifestPath: "Clarinet.toml",
      },
    },
    testTimeout: 60000,
    hookTimeout: 30000,
    fileParallelism: false,
    setupFiles: [
      "./node_modules/@stacks/clarinet-sdk/vitest-helpers/src/vitest.setup.ts",
    ],
  },
});
