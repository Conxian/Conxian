import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    viteEnvironment: "clarinet",
    environmentOptions: {
      clarinet: {
        manifest: "Clarinet.toml",
        coverage: {
          enabled: false,
        },
      },
    },
    testTimeout: 300000,
    hookTimeout: 120000,
    pool: undefined, // Disable pool to avoid timeout issues
  },
});
