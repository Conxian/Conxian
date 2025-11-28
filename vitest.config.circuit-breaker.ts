import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    viteEnvironment: "node",
    include: ["tests/circuit-breaker/**/*.test.ts"],
    testTimeout: 120000,
    hookTimeout: 60000,
    pool: "threads",
    poolOptions: {
      threads: {
        isolate: true,
        maxThreads: 2,
      },
    },
    setupFiles: ["./tests/setup.ts"],
    coverage: {
      reporter: ["text", "json", "html"],
      include: ["contracts/security/*.clar"],
      exclude: ["**/node_modules/**", "**/tests/**"],
    },
  },
});
