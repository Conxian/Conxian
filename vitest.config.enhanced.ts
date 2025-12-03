import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ["./tests/vitest.setup.ts"],
    testTimeout: 60000, // Increase timeout to 60 seconds
    hookTimeout: 60000,
    pool: undefined,
    // poolOptions: {
    //   forks: {
    //     minForks: 1,
    //     maxForks: 4, // Limit forks to avoid resource exhaustion
    //   },
    // },
  },
});

