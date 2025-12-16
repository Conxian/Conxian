import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "clarinet",
    environmentOptions: {
      clarinet: {
        manifestPath: "Clarinet.toml",
      },
    },
    setupFiles: ["./tests/vitest.setup.ts"],
    testTimeout: 120000,
    hookTimeout: 90000,
    pool: "threads",
    fileParallelism: false,
  },
});
