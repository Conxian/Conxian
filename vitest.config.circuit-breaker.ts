import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/circuit-breaker/**/*.test.ts"],
    testTimeout: 120000,
    hookTimeout: 60000,
    fileParallelism: false,
    setupFiles: ["./tests/vitest.setup.ts"],
    coverage: {
      reporter: ["text", "json", "html"],
      include: ["contracts/security/*.clar"],
      exclude: ["**/node_modules/**", "**/tests/**"],
    },
  },
});
