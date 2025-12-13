import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "clarinet",
    setupFiles: ["./tests/vitest.setup.ts"],
    environmentOptions: {
      clarinet: {
        manifestPath: "Clarinet.toml",
        coverage: false,
        costs: false,
      },
    },
    testTimeout: 300000,
    hookTimeout: 120000,
    pool: undefined, // Disable pool to avoid timeout issues
  },
});
