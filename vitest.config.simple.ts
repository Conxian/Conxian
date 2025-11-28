import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    viteEnvironment: "clarinet",
    environmentOptions: {
      clarinet: {
        manifest: "Clarinet.toml",
      },
    },
    testTimeout: 60000,
    hookTimeout: 30000,
    pool: "threads",
    poolOptions: {
      threads: {
        isolate: true,
        maxThreads: 2,
      },
    },
    setupFiles: [
      "./node_modules/@stacks/clarinet-sdk/vitest-helpers/src/vitest.setup.ts",
    ],
  },
});
