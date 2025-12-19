import { defineConfig } from 'vitest/config';
import { vitestSetupFilePath } from '@stacks/clarinet-sdk/vitest';

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/circuit-breaker/**/*.test.ts"],
    testTimeout: 120000,
    hookTimeout: 60000,
    fileParallelism: false,
    setupFiles: [vitestSetupFilePath, "./tests/vitest.setup.ts"],
    env: {
      CLARINET_MANIFEST_PATH: "./Clarinet.toml"
    },
    coverage: {
      reporter: ["text", "json", "html"],
      include: ["contracts/security/*.clar"],
      exclude: ["**/node_modules/**", "**/tests/**"],
    },
  },
});
