import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    viteEnvironment: "node",
    include: ["stacks/tests/trait-impl.spec.ts"],
    exclude: [],
    globals: true,
    testTimeout: 60000,
    hookTimeout: 30000,
    pool: "threads",
    poolOptions: {
      threads: {
        isolate: true,
        maxThreads: 2,
      },
    },
    // No Clarinet SDK setup files to avoid Clarity/Clarinet version coupling
    setupFiles: [],
  },
});
