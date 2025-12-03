import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "node",
    setupFiles: ["./tests/vitest.setup.ts"],
    // Only run the consolidated suite under tests/** in this enhanced config.
    include: ["tests/**/*.test.ts"],
    // Exclude legacy stacks SDK/spec tests that rely on the Clarinet Vitest
    // environment and global simnet. Those can be run separately with the
    // clarinet config if needed.
    exclude: ["stacks/**/*"],
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

